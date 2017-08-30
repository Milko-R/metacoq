(*i camlp4deps: "parsing/grammar.cma" i*)
(*i camlp4use: "pa_extend.cmp" i*)

open Term
open Template_AST
open Reify

DECLARE PLUGIN "template_coq_plugin"

let pp_constr fmt x = Pp.pp_with fmt (Printer.pr_constr x)
                    
let quote_string s =
  let rec aux i =
    if i = String.length s then []
    else s.[i] :: aux (i + 1)
  in aux 0

module TemplateASTQuoter =
struct
  type t = term
  type quoted_ident = char list
  type quoted_name = name
  type quoted_sort = sort
  type quoted_cast_kind = cast_kind
  type quoted_kernel_name = char list
  type quoted_inductive = inductive
  type quoted_decl = program -> program
  type quoted_program = program
  type quoted_int = Datatypes.nat
  type quoted_bool = bool

  type quoted_univ_instance = level list
  type quoted_mind_params = (ident * local_entry) list
  type quoted_ind_entry =
    quoted_ident * t * quoted_bool * quoted_ident list * t list
  type quoted_definition_entry = t * t option
  type quoted_mind_entry = mutual_inductive_entry
  type quoted_mind_finiteness = recursivity_kind
  type quoted_entry = (constant_entry, quoted_mind_entry) sum option

  open Names

  let quote_ident id =
    quote_string (Id.to_string id)
  let quote_name = function
    | Anonymous -> Coq_nAnon
    | Name i -> Coq_nNamed (quote_ident i)

  let rec quote_int i =
    if i = 0 then Datatypes.O else (Datatypes.S (quote_int (i - 1)))

  let quote_bool x = x

  let pos_of_universe i = BinNums.Coq_xH
                        
  let quote_sort s =
    let open Sorts in
    match s with
    | Prop Null -> Coq_sProp
    | Prop Pos -> Coq_sSet
    | Type i -> Coq_sType [] (* FIXME (pos_of_universe i) *)
              
  let quote_cast_kind = function
    | DEFAULTcast -> Cast
    | REVERTcast -> RevertCast
    | NATIVEcast -> NativeCast
    | VMcast -> VmCast
              
  let quote_kn kn = quote_string (Names.string_of_kn kn)
  let quote_inductive (kn, i) = Coq_mkInd (kn, i)
  let mkAnon = Coq_nAnon
  let mkName i = Coq_nNamed i
                  
  let mkRel n = Coq_tRel n
  let mkVar id = Coq_tVar id
  let mkSort s = Coq_tSort s
  let mkCast c k t = Coq_tCast (c,k,t)
  let mkUnknown trm = Coq_tUnknown (quote_string (Format.asprintf "%a" pp_constr trm))

  let mkConst c u = Coq_tConst (c, u)
  let mkProd na t b = Coq_tProd (na, t, b)
  let mkLambda na t b = Coq_tLambda (na, t, b)
  let mkApp f xs = Coq_tApp (f, Array.to_list xs)
  let mkInd i u = Coq_tInd (i, u)
  let mkConstruct (ind, i) u = Coq_tConstruct (ind, i, u)
  let mkLetIn na b t t' = Coq_tLetIn (na,b,t,t')
  let mkFix ((a,b),(ns,ts,ds)) =
    let rec seq f t =
      if f < t then
	f :: seq (f + 1) t
      else
	[]
    in
    let mk_fun xs i =
      { dname = Array.get ns i ;
        dtype = Array.get ts i ;
        dbody = Array.get ds i ;
        rarg = Array.get a i } :: xs
    in
    let defs = List.fold_left mk_fun [] (seq 0 (Array.length a)) in
    let block = List.rev defs in
    Coq_tFix (block, b)

  let mkCase (ind, npar) nargs p c brs =
    let info = (ind, npar) in
    let branches = List.map2 (fun br nargs ->  (nargs, br)) brs nargs in
    Coq_tCase (info,p,c,branches)

  let mkMutualInductive kn p r =
    (* FIXME: This is a quite dummy rearrangement *)
    let r = List.map (fun (i,r) ->
                (i,List.map (fun (id,t,n) -> (id,t),n) r)) r in
    fun pr ->
    PType (kn,p,r,pr)
  let mkConstant kn u t = fun pr -> PConstr (kn,u,t,pr)
  let mkAxiom kn t = fun pr -> PAxiom (kn,t,pr)
  let mkExt e p = e p
  let mkIn c = PIn c

  let quote_mind_finiteness = function
    | Decl_kinds.Finite -> Finite
    | Decl_kinds.CoFinite -> CoFinite
    | Decl_kinds.BiFinite -> BiFinite

  let quote_mind_params l =
    let map (id, body) =
      match body with
      | Left ty -> (id, LocalAssum ty)
      | Right trm -> (id, LocalDef trm)
    in List.map map l

  let quote_univ_level l =
    match Univ.Level.var_index l with
    | Some var -> LevelVar (quote_int var)
    | None ->
       let str = Univ.Level.to_string l in
       Level (quote_string str)

  let quote_univ_instance u =
    let arr = Univ.Instance.to_array u in
    CArray.map_to_list quote_univ_level arr

  let quote_one_inductive_entry (id, ar, b, consnames, constypes) =
    { mind_entry_typename = id;
      mind_entry_arity = ar;
      mind_entry_template = b;
      mind_entry_consnames = consnames;
      mind_entry_lc = constypes }

  let quote_mutual_inductive_entry (mf, mp, is, poly) =
    { mind_entry_record = None;
      mind_entry_finite = mf;
      mind_entry_params = mp;
      mind_entry_inds = List.map quote_one_inductive_entry is;
      mind_entry_polymorphic = poly;
      mind_entry_private = None }

  let quote_entry e =
    match e with
    | Some (Left (ty, body)) ->
       let entry = match body with
        | None -> ParameterEntry ty
        | Some b -> DefinitionEntry { definition_entry_type = ty;
                                      definition_entry_body = b }
       in Some (Left entry)
    | Some (Right mind_entry) ->
       Some (Right mind_entry)
    | None -> None
end

module TemplateASTReifier = Reify(TemplateASTQuoter)

include TemplateASTReifier
