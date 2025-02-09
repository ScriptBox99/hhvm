(*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the "hack" directory of this source tree.
 *
 *)

open Hh_prelude

(**
  * [module_] represents when a top level symbol is _definitely_ in a module.
  * The "root" of the module tree is the first element, with any children
  * in the second. This is to avoid [module_ option] having a weird state in
  * [Some []]: "we are in a module with no name."
  *)
type module_ = string * string list [@@deriving eq, show]

let of_string s =
  match String.split ~on:'.' s with
  | [] -> None
  | root :: children -> Some (root, children)

let of_maybe_string = Option.bind ~f:of_string

type t = module_ option [@@deriving eq, show]

let name_of (m, ms) = String.concat ~sep:"." (m :: ms)

(** [relate ~left ~right] returns the relate is between [left] and
 * [right] from the following options:
 * - [`Same]: These two modules are exactly the same; they can access each
 *    other's internal members.
 * - [`Disjoint]: These two modules are not in the same hierarchy; they cannot
 *   access each other's internal members at all.
 * - [`LeftSubRight]: [left] is a submodule of [right]; [left] can access
 *   [right]'s internal members.
 * - [`RightSubLeft]: [right] is a submodule of [left]; [right] can access
 *   [left]'s internal members
 *)
let rec relate ~(left : string list) ~(right : string list) =
  match (left, right) with
  | ([], []) -> `Same
  | (_, []) -> `LeftSubRight
  | ([], _) -> `RightSubLeft
  | (l :: ls, r :: rs) when String.equal l r -> relate ~left:ls ~right:rs
  | _ -> (* This is the case when l and r are disjoint *) `Disjoint

let can_access ~(current : Ast_defs.id option) ~(target : Ast_defs.id option) =
  match (current, target) with
  | (None, None)
  | (Some _, None) ->
    `Yes
  | (None, Some m) -> `Outside m
  | (Some ((_, m_current) as current), Some ((_, m_target) as target)) ->
    let normalize m =
      of_string m
      |> Option.map ~f:(fun (m, ms) -> m :: ms)
      |> Option.value ~default:[]
    in
    (match relate ~left:(normalize m_current) ~right:(normalize m_target) with
    | `Same
    | `LeftSubRight ->
      `Yes
    | `Disjoint
    | `RightSubLeft ->
      `Disjoint (current, target))
