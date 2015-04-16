
(**

  Krypto : Irmin Crypto Backend
  The kryptonite for protect your data of nasties

  TODO :
  Padding into blobs, and cut blobs on a defined size block -> We don't want to guess the size of content

*)


open Lwt


module Log = Log.Make(struct let section = "KRYPO" end)

module type CIPHER_BLOCK = Krypto_cipher.MAKER
module type AO_MAKER = Irmin.AO_MAKER
module type RW_MAKER = Irmin.RW_MAKER
module type AO = Irmin.AO
module type RW = Irmin.RW

module Make_KM = Krypto_km.Make
module Make_Cipher = Krypto_cipher.Make


module KRYPTO_AO (C: CIPHER_BLOCK) (S:AO_MAKER) (K: Irmin.Hash.S) (V: Tc.S0) = struct

    module AO = S(K)(V)

    type key = AO.key

    type value = AO.value

    type t = AO.t

    (* Cstruct blit for storing ctr into blob, and retreiving from blob *)
    let ctr = Cstruct.of_string "kryptonite"

    let to_cstruct x = Tc.write_cstruct (module V) x
    let of_cstruct x = Tc.read_cstruct (module V) x

    let create config task =
      AO.create config task

    let task t =
      AO.task t

    let read t key =
      AO.read t key >>= function
      | None -> return_none
      | Some v -> return (Some (of_cstruct (C.decrypt ~ctr (to_cstruct v))))


    let read_exn t key =
      try
        AO.read_exn t key >>=
          function x ->
                   return (of_cstruct (C.decrypt ~ctr (to_cstruct x)))
      with
      | Not_found -> fail Not_found

    let mem t k =
      AO.mem t k

    let add t v =
      to_cstruct v |> C.encrypt ~ctr |> of_cstruct |> AO.add t

  end


module Make (CB:CIPHER_BLOCK) (AO: AO_MAKER) (RW:RW_MAKER) (C: Irmin.Contents.S) (T: Irmin.Tag.S) (H: Irmin.Hash.S) =
  Irmin.Make(KRYPTO_AO(CB)(AO))(RW)(C)(T)(H)
