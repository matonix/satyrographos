open Core

module PackageFiles = struct
  include Map.Make(String)

  let union f = merge ~f:(fun ~key:key -> function
    | `Left v | `Right v -> Some v
    | `Both (x, y) -> f key x y
  )
end

module Json = struct
  include Yojson.Safe
  include Json_derivers.Yojson
end

module StringMap = Map.Make(String)
module JsonSet = Set.Make(Json)

type t = {
  hashes: (string list * Json.t) PackageFiles.t;
  files: string PackageFiles.t;
}
[@@deriving sexp, compare]

let empty = {
  hashes = PackageFiles.empty;
  files = PackageFiles.empty;
}


let show_file_list files =
  [%sexp_of: string list] files
  |> Sexp.to_string

let hash_map_singleton (k, x) =
  StringMap.singleton k (JsonSet.singleton x)

let to_string x =
  [%sexp_of: t] x
  |> Sexp.to_string

let hash_map_union =
  (* TODO use merge_skewed *)
  StringMap.merge ~f:(fun ~key:_ -> function
    | `Left v | `Right v -> Some v
    | `Both (x, y) -> Some(JsonSet.union x y)
  )

let validate_hash f abs_fs = function
  | (`Assoc a) ->
    List.map ~f:hash_map_singleton a
    |> List.fold_left ~f:hash_map_union ~init:StringMap.empty
    |> StringMap.filter ~f:(fun v -> JsonSet.length v > 1)
    |> StringMap.mapi ~f:(fun ~key:k ~data:v -> Printf.sprintf "Error in %s:\nField: %s\nValues: %s\nOriginally from: %s\n\n"
      f
      k
      (Json.to_string (`List (JsonSet.elements v)))
      (show_file_list abs_fs)
    )
    |> StringMap.data

  | _ -> [f ^ " is not an object. Originally from " ^ show_file_list abs_fs]

let validate p =
  PackageFiles.mapi p.hashes
    ~f:(fun ~key:f ~data:(abs_fs, h) -> validate_hash f abs_fs h)
  |> PackageFiles.data
  |> List.concat

let add_file f absolute_path p =
  if FilePath.is_relative absolute_path
  then failwith ("BUG: FilePath must be absolute but got " ^ absolute_path)
  else { p with files = PackageFiles.add_exn ~key:f ~data:absolute_path p.files }

let add_hash f abs_f p =
  let json = Json.from_file abs_f in
  { p with hashes = PackageFiles.add_exn ~key:f ~data:([abs_f], json) p.hashes }

let union p1 p2 =
  let handle_file_conflict f f1 f2 = match FileUtil.cmp f1 f2 with
    | None -> Some(f1)
    | Some(-1) -> failwith ("Cannot read either of files " ^ f ^ "\n  " ^ f1 ^ "\n  " ^ f2)
    | _ -> failwith ("Conflicting file " ^ f ^ "\n  " ^ f1 ^ "\n  " ^ f2)
  in
  let handle_hash_conflict f (f1, h1) (f2, h2) = match h1, h2 with
    | `Assoc a1, `Assoc a2 -> Some(List.append f1 f2, `Assoc (List.append a1 a2)) (* TODO: Handle conflicting cases*)
    | _, _ -> failwith ("Conflicting file " ^ f ^ "\n  " ^ show_file_list f1 ^ "\n and \n  " ^ show_file_list f2)
  in
  { hashes = PackageFiles.union handle_hash_conflict p1.hashes p2.hashes;
    files = PackageFiles.union handle_file_conflict p1.files p2.files;
  }

let%test "union: empty + empty = empty" =
  [%compare.equal: t] empty (union empty empty)

let%test "union: empty + p = empty" =
  let p = add_file "a" "/b" empty in
  [%compare.equal: t] p (union empty p)

let%test "union: p + empty = empty" =
  let p = add_file "a" "/b" empty in
  [%compare.equal: t] p (union p empty)

let read_dir d =
  let add acc f =
    let rel_f = FilePath.make_relative d f in
    if FilePath.is_subdir rel_f "hash"
    then add_hash rel_f f acc
    else add_file rel_f f acc
  in
  if FileUtil.test FileUtil.Is_dir d
  then FileUtil.(find ~follow:Follow Is_file d add empty)
  else failwith (d ^ " is not a package directory")

let write_dir d p =
  FileUtil.mkdir ~parent:true d;
  PackageFiles.iteri ~f:(fun ~key:path ~data:fullpath ->
    let file_dst = FilePath.concat d path in
    Printf.printf "Copying %s to %s\n" fullpath file_dst;
    FileUtil.mkdir ~parent:true (FilePath.dirname file_dst);
    FileUtil.cp [fullpath] file_dst
  ) p.files;
  PackageFiles.iteri ~f:(fun ~key:path ~data:(_, h) ->
    let file_dst = FilePath.concat d path in
    Printf.printf "Generating %s\n" file_dst;
    FileUtil.mkdir ~parent:true (FilePath.dirname file_dst);
    Json.to_file file_dst h
  ) p.hashes


let mark_filename = ".satyrographos"
let mark_managed_dir d =
  FileUtil.mkdir ~parent:true d;
  FileUtil.touch (FilePath.concat d mark_filename)

let is_managed_dir d =
  FileUtil.test FileUtil.Is_file (FilePath.concat d mark_filename)
