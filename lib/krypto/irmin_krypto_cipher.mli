

module type KEY_MANAGEMENT = Irmin_krypto_km.KEY_MANAGEMENT



module type CTR_MODE = sig

    type key

    val of_secret : Cstruct.t -> key

    val stream  : key:key -> ctr:Cstruct.t -> ?off:int -> int -> Cstruct.t
    val encrypt : key:key -> ctr:Cstruct.t -> ?off:int -> Cstruct.t -> Cstruct.t
    val decrypt : key:key -> ctr:Cstruct.t -> ?off:int -> Cstruct.t -> Cstruct.t

  end




module type CIPHER = sig

    val encrypt : ctr:Cstruct.t -> Cstruct.t -> Cstruct.t
    val decrypt : ctr:Cstruct.t -> Cstruct.t -> Cstruct.t

end


module Make_CTR (KM: KEY_MANAGEMENT) (C:CTR_MODE) : CIPHER
