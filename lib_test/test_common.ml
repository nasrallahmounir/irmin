(*
 * Copyright (c) 2013 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Irmin_unix

let () =
  Log.set_log_level Log.DEBUG;
  Log.color_on ();
  Log.set_output stderr

let cmp_opt fn x y =
  match x, y with
  | Some x, Some y -> fn x y
  | None  , None   -> true
  | Some _, None
  | None  , Some _ -> false

let printer_opt fn = function
  | None   -> "<none>"
  | Some v -> fn v

let rec cmp_list fn x y =
  match x, y with
  | xh::xt, yh::yt -> fn xh yh && cmp_list fn xt yt
  | []    , []     -> true
  | _              -> false

let printer_list fn = function
  | [] -> "[]"
  | l  -> Printf.sprintf "[ %s ]"
            (String.concat ", " (List.map fn l))

let line msg =
  let line () = Alcotest.line stderr ~color:`Yellow '-' in
  line ();
  Log.info "ASSERT %s" msg;
  line ()

module Make (S: Irmin.S) = struct

  let cmp_list eq comp l1 l2 =
    cmp_list eq (List.sort comp l1) (List.sort comp l2)

  let error msg expected got =
    let msg = Printf.sprintf "Fail %s: expecting %s, got %s" msg expected got in
    failwith msg

  let aux cmp printer msg x y =
    line msg;
    if not (cmp x y) then error msg (printer x) (printer y)

  let assert_equal (type t) (module S: Tc.S0 with type t = t) msg =
    aux S.equal (Tc.show (module S)) msg

  module Set (S: Tc.S0) = struct
    module L = Tc.List(S)
    include L
    let compare x y =
      let x = List.sort S.compare x in
      let y = List.sort S.compare y in
      L.compare x y
    let equal x y =
      let x = List.sort S.compare x in
      let y = List.sort S.compare y in
      L.equal x y
  end

  module KV = S.Private.Contents.Key
  module KN = S.Private.Node.Key
  module KC = S.Head

  module RV = Tc.App1(Irmin.Merge.Result)(Tc.Option(KV))
  module RN = Tc.App1(Irmin.Merge.Result)(KN)
  module RC = Tc.App1(Irmin.Merge.Result)(KC)

  module Contents = S.Private.Contents
  module Node = S.Private.Node
  module Commit = S.Private.Commit

  module T = S.Tag
  module K = S.Key
  module V = S.Val
  module N = Node.Val
  module C = Commit.Val

  module Succ = Set( Tc.Pair(S.Key.Step)(S.Private.Node.Key) )

end

open Lwt

let create: (module Irmin.S_MAKER) -> [`String | `Json] -> (module Irmin.S) =
  fun (module B) c ->
    let (module C: Irmin.Contents.S) = match c with
      | `String -> (module Irmin.Contents.String)
      | `Json   -> (module Irmin.Contents.Json)
    in
    let module S = Irmin.Basic(B)(C) in (module S)

type kind = [`Mem
	    | `Fs
	    | `Git
	    | `Link_FS_Chunck_Krypto
	    | `Link_MEM_Chunck_Krypto
	    | `Link_FS_Chunck
	    | `Link_MEM_Chunck
	    | `Http of kind]

type t = {
  name  : string;
  kind  : kind;
  cont  : [`Json | `String];
  init  : unit -> unit Lwt.t;
  clean : unit -> unit Lwt.t;
  config: Irmin.config;
  store : (module Irmin.S);
}

let none () =
  return_unit

let string_of_contents = function
  | `Json   -> "-json"
  | `String -> ""

let mem_store = create (module Irmin_mem.Make)
let fs_store = create (module Irmin_fs.Make)
let http_store = create (module Irmin_http.Make)
let git_store = create (module Irmin_git.FS)

module AO = Irmin_fs.AO 
module RW = Irmin_fs.RW

(* Links store with mem *)
module LINK_MEM = Irmin_link.MEM

(* Links store with FS *)
module LINK_FS = Irmin_link.FS
	      
(* Chunck store with mem *)		       
module CHUNCK = Irmin_chunck.CHUNCK_AO (AO)

(* Links on memory and chunck store*)
module MEM_CHUNCK_STORE = Irmin_link.Make (LINK_MEM) (CHUNCK) (RW)
let link_mem_chunck_store = create (module MEM_CHUNCK_STORE)

(* Links on file-system and chunck store*)
module FS_CHUNCK_STORE = Irmin_link.Make (LINK_FS) (CHUNCK) (RW)
let link_fs_chunck_store = create (module FS_CHUNCK_STORE)
			  
(* Krypto and Chunck *)
open Nocrypto.Cipher_block
module KRYPTO_KM = Irmin_krypto.Make_km
module KRYPTO_AES = Irmin_krypto.Make_cipher (KRYPTO_KM) (AES.CTR)
module CHUNCK_KRYPTO = Irmin_krypto.KRYPTO_AO (KRYPTO_AES) (CHUNCK)

(* Links on memory, chunck and krypto store*)
module MEM_KRYPTO_CHUNCK_STORE = Irmin_link.Make (LINK_MEM) (CHUNCK_KRYPTO) (RW)
let link_mem_chunck_krypto_store = create (module MEM_KRYPTO_CHUNCK_STORE)

(* Links on file-system. chunck and krypto store*)
module FS_KRYPTO_CHUNCK_STORE = Irmin_link.Make (LINK_FS) (CHUNCK_KRYPTO) (RW)
let link_fs_chunck_krypto_store = create (module FS_KRYPTO_CHUNCK_STORE)

