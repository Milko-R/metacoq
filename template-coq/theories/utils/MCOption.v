From Coq Require Import List.

Definition option_get {A} (default : A) (x : option A) : A
  := match x with
     | Some x => x
     | None => default
     end.

Definition on_some {A} (P : A -> Type) (o : option A) :=
  match o with
  | Some t => P t
  | None => False
  end.

Definition on_Some {A} (P : A -> Prop) : option A -> Prop :=
  fun x => match x with
        | Some x => P x
        | None => False
        end.

Definition on_Some_or_None {A} (P : A -> Prop) : option A -> Prop :=
  fun x => match x with
        | Some x => P x
        | None => True
        end.

Definition option_default {A B} (f : A -> B) (o : option A) (b : B) :=
  match o with Some x => f x | None => b end.

Lemma some_inj {A} {x y : A} : Some x = Some y -> x = y.
Proof.
  now intros [=].
Qed.


Fixpoint map_option_out {A} (l : list (option A)) : option (list A) :=
  match l with
  | nil => Some nil
  | hd :: tl => match hd, map_option_out tl with
                | Some hd, Some tl => Some (hd :: tl)
                | _, _ => None
                end
  end.

Lemma map_option_out_map_option_map {A} (l : list (option A)) (f : A -> A) :
  map_option_out (map (option_map f) l) =
  option_map (map f) (map_option_out l).
Proof.
  induction l; simpl; auto.
  destruct (option_map f a) eqn:fa.
  rewrite IHl. destruct (map_option_out l). simpl in *.
  destruct a; simpl in *; congruence.
  simpl. destruct a; reflexivity.
  destruct a; simpl in *; congruence.
Qed.

Lemma option_map_two {A B C} (f : A -> B) (g : B -> C) x
  : option_map g (option_map f x) = option_map (fun x => g (f x)) x.
Proof.
  destruct x; reflexivity.
Qed.

Lemma option_map_ext {A B} (f g : A -> B) (H : forall x, f x = g x)
  : forall z, option_map f z = option_map g z.
Proof.
  intros []; cbn; congruence.
Qed.
