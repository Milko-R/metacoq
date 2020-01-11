From Coq Require Import Bool String List Program BinPos Compare_dec Arith Lia
     Classes.CRelationClasses ProofIrrelevance.
From MetaCoq.Template Require Import config Universes monad_utils utils BasicAst
     AstUtils UnivSubst.
From MetaCoq.PCUIC Require Import PCUICAst PCUICAstUtils PCUICInduction
     PCUICReflect PCUICLiftSubst PCUICUnivSubst PCUICTyping
     PCUICCumulativity PCUICPosition PCUICEquality PCUICNameless
     PCUICAlpha PCUICNormal PCUICInversion PCUICCumulativity PCUICReduction
     PCUICConfluence PCUICConversion PCUICContextConversion PCUICValidity
     PCUICParallelReductionConfluence PCUICWeakeningEnv
     PCUICClosed PCUICPrincipality PCUICSubstitution
     PCUICWeakening PCUICGeneration PCUICUtils.

From Equations Require Import Equations.

Require Import Equations.Prop.DepElim.
Require Import Equations.Type.Relation_Properties.
Require Import ssreflect ssrbool.

Definition same_shape (d d' : context_decl) := 
  match decl_body d, decl_body d' with
  | None, None => True
  | Some _, Some _ => True
  | _, _ => False
  end.
  
Definition same_ctx_shape (Γ Γ' : context) :=
  context_relation (fun _ _ => same_shape) Γ Γ'.
  
Hint Unfold same_ctx_shape : core.

Lemma same_ctx_shape_app Γ Γ' Δ Δ' : same_ctx_shape Γ Γ' -> 
  same_ctx_shape Δ Δ' ->
  same_ctx_shape (Γ ++ Δ)%list (Γ' ++ Δ')%list.
Proof.
  induction 1; simpl; try constructor; auto. 
  apply IHcontext_relation. auto.
  apply IHcontext_relation. auto.
Qed.

Lemma same_ctx_shape_rev Γ Γ' : same_ctx_shape Γ Γ' -> 
  same_ctx_shape (List.rev Γ) (List.rev Γ').
Proof.
  induction 1; simpl; try constructor.
  apply same_ctx_shape_app; auto. repeat constructor.
  apply same_ctx_shape_app; auto. repeat constructor.
Qed.

Lemma context_assumptions_app Γ Γ' : context_assumptions (Γ ++ Γ')%list = 
  context_assumptions Γ + context_assumptions Γ'.
Proof.
  induction Γ; simpl; auto.
  destruct a as [? [?|] ?]; simpl; auto.
Qed.

Lemma instantiate_params_ok ctx ctx' pars t : 
  same_ctx_shape ctx ctx' -> #|pars| = context_assumptions ctx ->
  ∑ h, instantiate_params ctx pars (it_mkProd_or_LetIn ctx' t) = Some h.
Proof.
  intros Hctx Hpars. rewrite instantiate_params_.
  apply same_ctx_shape_rev in Hctx.
  rewrite -(List.rev_involutive ctx').
  rewrite -(List.rev_involutive ctx) in Hpars.
  generalize (@nil term).
  induction Hctx in t, pars, Hpars |- *.
  - simpl. destruct pars; try discriminate. simpl in Hpars. intros l.
    now eexists (subst0 l _).
  - destruct pars; try discriminate.
    simpl in Hpars. rewrite context_assumptions_app in Hpars.
    simpl in Hpars. elimtype False. lia.
    simpl in Hpars. rewrite context_assumptions_app in Hpars.
    rewrite Nat.add_1_r in Hpars. noconf Hpars.
    simpl in H.
    intros l.
    destruct (IHHctx _ t H (t0 :: l)).
    simpl. exists x.
    now rewrite it_mkProd_or_LetIn_app.
  - intros l.
    simpl in Hpars. rewrite context_assumptions_app in Hpars.
    simpl in Hpars. rewrite Nat.add_0_r in Hpars. simpl.
    rewrite it_mkProd_or_LetIn_app.
    simpl. apply IHHctx. auto.
Qed.

Lemma reln_length Γ Γ' n : #|reln Γ n Γ'| = #|Γ| + context_assumptions Γ'.
Proof.
  induction Γ' in n, Γ |- *; simpl; auto.
  destruct a as [? [b|] ?]; simpl; auto.
  rewrite Nat.add_1_r. simpl. rewrite IHΓ' => /= //.
Qed.

Lemma to_extended_list_k_length Γ n : #|to_extended_list_k Γ n| = context_assumptions Γ.
Proof.
  now rewrite /to_extended_list_k reln_length.
Qed.
