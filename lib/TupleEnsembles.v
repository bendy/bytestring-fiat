Require Export Coq.Sets.Ensembles.

Require Import
  ByteString.Lib.LibExt
  ByteString.Lib.Relations
  ByteString.Lib.Same_set.

Generalizable All Variables.

Section TupleEnsemble.

Variables A B : Type.

Definition EMap := Ensemble (A * B).

Definition Empty : EMap := Empty_set _.

Definition Single (a : A) (b : B) : EMap := Singleton _ (a, b).

Definition Lookup (a : A) (b : B) (r : EMap) := In _ r (a, b).

Definition Functional (r : EMap) :=
  forall addr blk1, Lookup addr blk1 r ->
  forall blk2, Lookup addr blk2 r -> blk1 = blk2.

Definition Same (x y : EMap) : Prop :=
  forall a b, Lookup a b x <-> Lookup a b y.

Global Program Instance Same_Equivalence : Equivalence Same.
Obligation 1.
  constructor; auto.
Qed.
Obligation 2.
  constructor; apply H; auto.
Qed.
Obligation 3.
  constructor; intros.
    apply H0, H; auto.
  apply H, H0; auto.
Qed.

Lemma Same_Same_set : forall x y, Same x y <-> Same_set _ x y.
Proof.
  unfold Same, Lookup.
  split; intros.
    split; intros;
    intros ? H0;
    destruct x0;
    apply H; assumption.
  split; intros;
  apply H; assumption.
Qed.

Global Program Instance Lookup_Proper :
  Proper (eq ==> eq ==> Same ==> Basics.impl) Lookup.
Obligation 1. relational; unfold Basics.impl; apply H1. Qed.

Global Program Instance Lookup_Proper_flip :
  Proper (eq ==> eq ==> Same --> Basics.impl) Lookup.
Obligation 1. relational; unfold Basics.impl; apply H1. Qed.

Definition Member (a : A) (r : EMap) := exists b, Lookup a b r.

Definition Member_dec (a : A) (r : EMap) : Member a r \/ ~ Member a r.
Proof.
  unfold Member.
  elim (Classical_Prop.classic (exists b, Lookup a b r));
  intuition.
Qed.

Definition Insert (a : A) (b : B) (r : EMap)
           (H : forall b' : B, ~ Lookup a b' r) : EMap :=
  Add _ r (a, b).

Definition Remove (a : A) (r : EMap) : EMap :=
  Setminus _ r (fun p => fst p = a).

Program Definition Update (a : A) (b : B) (r : EMap) :
  EMap := Insert a b (Remove a r) _.
Obligation 1. firstorder. Qed.

Definition Map {C} (f : A -> B -> C) (r : EMap) : Ensemble (A * C) :=
  fun p => exists b : B, Lookup (fst p) b r /\ snd p = f (fst p) b.

Definition Relate {C D} (f : A -> B -> C -> D -> Prop) (r : EMap) :
  Ensemble (C * D) :=
  fun p => exists k' e', Lookup k' e' r /\ f k' e' (fst p) (snd p).

Lemma Map_left_identity : forall r, Same r (Map (fun _ x => x) r).
Proof.
  unfold Map; split; intros.
    eexists b.
    intuition.
  do 2 destruct H.
  simpl in *.
  rewrite H0.
  assumption.
Qed.

Lemma Map_right_identity : forall r, Same (Map (fun _ x => x) r) r.
Proof.
  unfold Map; split; intros.
    do 2 destruct H.
    simpl in *.
    rewrite H0.
    assumption.
  eexists b.
  intuition.
Qed.

Lemma Map_composition : forall f g r,
  Same (Map (fun k e => f k (g k e)) r) (Map f (Map g r)).
Proof.
  unfold Map; split; intros.
    destruct H.
    destruct H; simpl in *.
    subst.
    exists (g a x); simpl in *.
    split; trivial.
    exists x; simpl.
    intuition.
  destruct H.
  destruct H; simpl in *.
  subst.
  destruct H; simpl in *.
  exists x0; simpl in *.
  destruct H.
  intuition.
  rewrite <- H0.
  reflexivity.
Qed.

Definition Move (a a' : A) (r : EMap) : EMap :=
  Relate (fun k e k' e' =>
            e = e' /\ ((k' = a' /\ k = a) \/ (k' <> a /\ k = k'))) r.

Definition Filter (P : A -> B -> Prop) (r : EMap) :
  EMap :=
  fun p => Lookup (fst p) (snd p) r /\ P (fst p) (snd p).

Definition Define (P : A -> Prop) (b : B) (r : EMap) :
  EMap :=
  Ensembles.Union
    _ (fun p => P (fst p) /\ In _ (Singleton _ b) (snd p))
      (Filter (fun k _ => ~ P k) r).

Definition Modify (a : A) (f : B -> B) (r : EMap) :
  EMap :=
  Relate (fun k e k' e' => k = k' /\ IF k' = a then e' = f e else e' = e) r.

Definition All (P : A -> B -> Prop) (r : EMap) : Prop :=
  forall a b, Lookup a b r -> P a b.

Definition Any (P : A -> B -> Prop) (r : EMap) : Prop :=
  exists a b, Lookup a b r /\ P a b.

Lemma Lookup_Empty : forall a b, ~ Lookup a b Empty.
Proof. firstorder. Qed.

Lemma Lookup_Single : forall a a' b b',
  a = a' -> b = b' -> Lookup a b (Single a' b').
Proof. intros; rewrite H, H0; firstorder. Qed.

Lemma Lookup_Single_inv : forall a b c d,
  Lookup a b (Single c d) -> a = c /\ b = d.
Proof. split; inversion H; reflexivity. Qed.

Lemma Lookup_Insert : forall a b c d r H,
  (a = c /\ b = d) \/ (a <> c /\ Lookup a b r)
    -> Lookup a b (Insert c d r H).
Proof.
  intros.
  intuition.
    rewrite H0, H2.
    right; constructor.
  left.
  exact H2.
Qed.

Lemma Lookup_Insert_inv : forall a b c d r H,
  Lookup a b (Insert c d r H)
    -> (a = c /\ b = d) \/ (a <> c /\ Lookup a b r).
Proof.
  intros.
  inversion H0; clear H0.
    subst.
    right.
    firstorder.
    unfold not; intros; subst.
    contradiction (H b).
  inversion H1; clear H1.
  firstorder.
Qed.

Lemma Lookup_Remove : forall a b a' r,
  Lookup a b r -> a <> a' -> Lookup a b (Remove a' r).
Proof. firstorder. Qed.

Lemma Lookup_Remove_ex_r : forall a b r,
  Lookup a b r -> exists a', a <> a' -> Lookup a' b (Remove a r).
Proof. firstorder. Qed.

Lemma Lookup_Remove_inv : forall a b a' r,
  Lookup a b (Remove a' r) -> a <> a' /\ Lookup a b r.
Proof. firstorder. Qed.

Lemma Lookup_Update : forall a b a' b' r,
  (a = a' /\ b = b') \/ (a <> a' /\ Lookup a b r)
    -> Lookup a b (Update a' b' r).
Proof.
  intros.
  intuition.
    rewrite H, H1.
    right; constructor.
  left; constructor.
    exact H1.
  exact H.
Qed.

Lemma Lookup_Update_eq : forall a b b' r,
  b = b' -> Lookup a b (Update a b' r).
Proof.
  intros; subst.
  apply Lookup_Update.
  left; intuition.
Qed.

Lemma Lookup_Update_neq : forall a a' b b' r,
  a <> a' -> Lookup a b r -> Lookup a b (Update a' b' r).
Proof.
  intros; subst.
  apply Lookup_Update.
  right; intuition.
Qed.

Lemma Lookup_Update_inv : forall a b a' b' r,
  Lookup a b (Update a' b' r)
    -> (a = a' /\ b = b') \/ (a <> a' /\ Lookup a b r).
Proof.
  intros.
  inversion H; clear H.
    firstorder.
  inversion H0; clear H0.
  firstorder.
Qed.

Lemma Lookup_Update_idem : forall a b r,
  Functional r ->
  (forall a a' : A, a = a' \/ a <> a') ->
    Lookup a b r -> Same r (Update a b r).
Proof.
  split; intros.
    apply Lookup_Update.
    destruct (H0 a0 a).
      left; intuition; subst.
      eapply H; eauto.
    right; intuition.
  apply Lookup_Update_inv in H2.
  firstorder; subst; assumption.
Qed.

Lemma Lookup_Relate : forall a b c d (f : A -> B -> A -> B -> Prop) r,
  Lookup a b r -> f a b c d -> Lookup c d (Relate f r).
Proof. firstorder. Qed.

Lemma Lookup_Relate_inv : forall a b (f : A -> B -> A -> B -> Prop) r,
  Lookup a b (Relate f r) -> exists a' b', f a' b' a b /\ Lookup a' b' r.
Proof.
  intros.
  inversion H; clear H.
  firstorder.
Qed.

Lemma Lookup_Move : forall k e a a' r,
  (IF k = a'
   then Lookup a e r
   else k <> a /\ Lookup k e r)
    -> Lookup k e (Move a a' r).
Proof. firstorder. Qed.

Lemma Lookup_Move_inv : forall k e a a' r,
  Lookup k e (Move a a' r)
    -> (k = a' /\ Lookup a e r) \/ (k <> a /\ Lookup k e r).
Proof.
  firstorder;
  simpl in *; subst;
  firstorder.
Qed.

Lemma Lookup_Map : forall a b f r,
  (exists b', f a b' = b /\ Lookup a b' r) -> Lookup a b (Map f r).
Proof. firstorder. Qed.

Lemma Lookup_Map_inv : forall a b f r,
  Lookup a b (Map f r) -> exists b', f a b' = b /\ Lookup a b' r.
Proof.
  intros.
  inversion H; clear H.
  firstorder.
Qed.

Lemma Lookup_Map_set : forall a b f r,
  (exists p', f p' = (a, b) /\ Lookup (fst p') (snd p') r)
    -> Lookup a b (Map_set f r).
Proof.
  unfold Map_set, Lookup, Ensembles.In; simpl.
  intuition.
  destruct H.
  rewrite <- surjective_pairing in H.
  exists x; simpl.
  intuition.
Qed.

Lemma Lookup_Map_set_inv : forall a b f r,
  Lookup a b (Map_set f r)
    -> exists p', f p' = (a, b) /\ Lookup (fst p') (snd p') r.
Proof.
  intros.
  inversion H; clear H.
  exists x.
  unfold Lookup.
  rewrite <- surjective_pairing.
  firstorder.
Qed.

Lemma Lookup_Filter : forall a b P r,
  Lookup a b r /\ P a b -> Lookup a b (Filter P r).
Proof. firstorder. Qed.

Lemma Lookup_Filter_inv : forall a b P r,
  Lookup a b (Filter P r) -> P a b /\ Lookup a b r.
Proof. firstorder. Qed.

Lemma Lookup_Union : forall a b r r',
  Lookup a b r \/ Lookup a b r'
    -> Lookup a b (Union (A * B) r r').
Proof.
  firstorder.
    left; exact H.
  right; exact H.
Qed.

Lemma Lookup_Union_inv : forall a b r r',
  Lookup a b (Union (A * B) r r')
    -> Lookup a b r \/ Lookup a b r'.
Proof.
  firstorder.
  unfold Lookup, Ensembles.In in *.
  apply Constructive_sets.Union_inv in H.
  intuition.
Qed.

Lemma Lookup_Define : forall a b c P r,
  (IF P a then In _ (Singleton _ c) b else Lookup a b r)
    -> Lookup a b (Define P c r).
Proof.
  unfold Define; intros.
  apply Lookup_Union.
  do 2 destruct H.
    left.
    unfold Lookup, Ensembles.In; simpl.
    intuition.
  right.
  apply Lookup_Filter.
  intuition.
Qed.

Lemma Lookup_Define_inv : forall a b c P r,
  Lookup a b (Define P c r)
    -> IF P a
       then In _ (Singleton _ c) b
       else Lookup a b r.
Proof.
  unfold Define; intros.
  apply Lookup_Union_inv in H.
  destruct H.
    firstorder.
  apply Lookup_Filter_inv in H.
  firstorder.
Qed.

Lemma Lookup_Modify : forall a b a' f r,
  (a = a' /\ exists b', f b' = b /\ Lookup a b' r)
    \/ (a <> a' /\ Lookup a b r)
    -> Lookup a b (Modify a' f r).
Proof.
  firstorder;
  simpl in *; subst;
  firstorder.
Qed.

Lemma Lookup_Modify_inv : forall a b a' f r,
  Lookup a b (Modify a' f r)
    -> (a = a' /\ exists b', f b' = b /\ Lookup a b' r)
         \/ (a <> a' /\ Lookup a b r).
Proof.
  firstorder;
  simpl in *; subst;
  firstorder.
Qed.

Lemma Lookup_Member : forall a b r,
  Lookup a b r -> Member a r.
Proof. firstorder. Qed.

Lemma Member_Lookup_not : forall a r,
  ~ Member a r -> forall b, ~ Lookup a b r.
Proof. firstorder. Qed.

Lemma All_Remove : forall a P r,
  All P r -> All P (Remove a r).
Proof. firstorder. Qed.

Lemma All_Remove_inv : forall a P r,
  All P (Remove a r) -> ~ Member a r -> All P r.
Proof.
  intros.
  intros ???.
  apply H.
  apply Lookup_Remove.
    assumption.
  unfold not; intros.
  subst.
  unfold Member in H0.
  Require Import Classical_Pred_Type.
  apply not_ex_all_not with (n:=b) in H0.
  contradiction.
Qed.

Lemma All_Remove_Lookup_inv : forall a P r,
  All P (Remove a r) -> forall a' b', a' <> a -> Lookup a' b' r -> P a' b'.
Proof. intros; apply H, Lookup_Remove; trivial. Qed.

Lemma All_Update_inv : forall k e P r,
  All P (Update k e r) -> P k e /\ All P (Remove k r).
Proof.
  intros.
  split.
    apply H, Lookup_Update.
    left; auto.
  intros ???.
  apply Lookup_Remove_inv in H0.
  destruct H0.
  apply H, Lookup_Update.
  right; intuition.
Qed.

Definition Unique P a r := All (fun a b => P a b = false) (Remove a r).

End TupleEnsemble.

Arguments Functional : default implicits.
Arguments Empty {_ _} _.
Arguments Single : default implicits.
Arguments Insert : default implicits.
Arguments Remove : default implicits.
Arguments Update : default implicits.
Arguments Modify : default implicits.
Arguments Move : default implicits.
Arguments Filter : default implicits.
Arguments Map : default implicits.
Arguments Relate : default implicits.
Arguments All : default implicits.
Arguments Any : default implicits.
Arguments Define : default implicits.
Arguments Lookup : default implicits.
Arguments Same : default implicits.
Arguments Member : default implicits.

Arguments Lookup_Empty : default implicits.

Ltac t H :=
  unfold Relate;
  split; intros;
  repeat destruct H;
  simpl in *; subst;
  firstorder;
  simpl in *; subst;
  firstorder.

Lemma Relate_left_identity : forall A B (r : EMap A B),
  Same r (Relate (fun k x k' x' => k = k' /\ x = x') r).
Proof. t H. Qed.

Lemma Relate_right_identity : forall A B (r : EMap A B),
  Same (Relate (fun k x k' x' => k = k' /\ x = x') r) r.
Proof. t H. Qed.

Lemma Relate_composition :
  forall A B C D E F
         (f : C -> D -> E -> F -> Prop) (g : A -> B -> C -> D -> Prop) r,
    Same (Relate (fun k e k' e' =>
                  exists k'' e'', g k e k'' e'' /\ f k'' e'' k' e') r)
         (Relate f (Relate g r)).
Proof. t H; exists x1; exists x2; t H. Qed.

Ltac teardown :=
  match goal with
  | [ H : Lookup _ _ Empty            |- _ ] => contradiction (Lookup_Empty H)
  | [ H : Lookup _ _ (Single _ _)     |- _ ] => apply Lookup_Single_inv in H
  | [ H : Lookup _ _ (Insert _ _ _ _) |- _ ] => apply Lookup_Insert_inv in H
  | [ H : Lookup _ _ (Remove _ _)     |- _ ] => apply Lookup_Remove_inv in H
  | [ H : Lookup _ _ (Update _ _ _)   |- _ ] => apply Lookup_Update_inv in H
  | [ H : Lookup _ _ (Move _ _ _)     |- _ ] => apply Lookup_Move_inv in H
  | [ H : Lookup _ _ (Map _ _)        |- _ ] => apply Lookup_Map_inv in H
  | [ H : Lookup _ _ (Map_set _ _)    |- _ ] => apply Lookup_Map_set_inv in H
  | [ H : Lookup _ _ (Relate _ _)     |- _ ] => apply Lookup_Relate_inv in H
  | [ H : Lookup _ _ (Filter _ _)     |- _ ] => apply Lookup_Filter_inv in H
  | [ H : Lookup _ _ (Define _ _ _)   |- _ ] => apply Lookup_Define_inv in H
  | [ H : Lookup _ _ (Modify _ _ _)   |- _ ] => apply Lookup_Modify_inv in H
  | [ H : Lookup _ _ (Union _ _ _)    |- _ ] => apply Lookup_Union_inv in H

  | [ H : Member _ Empty            |- _ ] => unfold Member in H
  | [ H : Member _ (Single _ _)     |- _ ] => unfold Member in H
  | [ H : Member _ (Insert _ _ _ _) |- _ ] => unfold Member in H
  | [ H : Member _ (Remove _ _)     |- _ ] => unfold Member in H
  | [ H : Member _ (Update _ _ _)   |- _ ] => unfold Member in H
  | [ H : Member _ (Move _ _ _)     |- _ ] => unfold Member in H
  | [ H : Member _ (Map _ _)        |- _ ] => unfold Member in H
  | [ H : Member _ (Map_set _ _)    |- _ ] => unfold Member in H
  | [ H : Member _ (Relate _ _)     |- _ ] => unfold Member in H
  | [ H : Member _ (Filter _ _)     |- _ ] => unfold Member in H
  | [ H : Member _ (Define _ _ _)   |- _ ] => unfold Member in H
  | [ H : Member _ (Modify _ _ _)   |- _ ] => unfold Member in H
  | [ H : Member _ (Union _ _ _)    |- _ ] => unfold Member in H

  | [ |- Lookup _ _ Empty            ] => apply Lookup_Empty
  | [ |- Lookup _ _ (Single _ _)     ] => apply Lookup_Single
  | [ |- Lookup _ _ (Insert _ _ _ _) ] => apply Lookup_Insert
  | [ |- Lookup _ _ (Remove _ _)     ] => apply Lookup_Remove
  | [ |- Lookup ?A _ (Update ?A _ _) ] => apply Lookup_Update_eq
  | [ H : ?A = ?B  |- Lookup ?A _ (Update ?B _ _) ] => apply Lookup_Update_eq
  | [ H : ?A <> ?B |- Lookup ?A _ (Update ?B _ _) ] => apply Lookup_Update_neq
  | [ |- Lookup _ _ (Update _ _ _)   ] => apply Lookup_Update_eq ||
                                          apply Lookup_Update
  | [ |- Lookup _ _ (Move _ _ _)     ] => apply Lookup_Move
  | [ |- Lookup _ _ (Map _ _)        ] => apply Lookup_Map
  | [ |- Lookup _ _ (Map_set _ _)    ] => apply Lookup_Map_set
  | [ |- Lookup _ _ (Relate _ _)     ] => apply Lookup_Relate
  | [ |- Lookup _ _ (Filter _ _)     ] => apply Lookup_Filter
  | [ |- Lookup _ _ (Define _ _ _)   ] => apply Lookup_Define
  | [ |- Lookup _ _ (Modify _ _ _)   ] => apply Lookup_Modify
  | [ |- Lookup _ _ (Union _ _ _)    ] => apply Lookup_Union

  | [ H : Lookup ?X ?Y ?R |- Member ?X ?R ] => exists Y; exact H

  (* | [ H1 : All _ (Remove _ _)   |- _ ] => apply All_Remove_inv in H1 *)
  (* | [ H1 : All _ (Update _ _ _) |- _ ] => apply All_Update_inv in H1 *)

  | [ |- All _ (Remove _ _) ] => apply All_Remove

  | [ H1 : All ?P ?R, H2 : Lookup ?X ?Y ?R |- _ ] =>
    specialize (H1 _ _ H2); simpl in H1

  | [ H : IF _ then _ else _ |- _ ] => destruct H
  | [ H : _ /\ _             |- _ ] => destruct H
  | [ H : _ \/ _             |- _ ] => destruct H
  | [ H : _ * _              |- _ ] => destruct H
  | [ H : exists _, _        |- _ ] => destruct H
  | [ H : @sig _ _           |- _ ] => destruct H
  | [ H : @sig2 _ _ _        |- _ ] => destruct H
  | [ H : @sigT _ _          |- _ ] => destruct H
  | [ H : @sigT2 _ _ _       |- _ ] => destruct H
  | [ H : bool               |- _ ] => destruct H
  | [ H : option _           |- _ ] => destruct H
  | [ H : sum _ _            |- _ ] => destruct H
  | [ H : sumor _ _          |- _ ] => destruct H
  | [ H : sumbool _ _        |- _ ] => destruct H

  | [ H : forall x, Some ?X = Some x -> _  |- _ ] => specialize (H X eq_refl)
  | [ H : forall x y, Some (?X, ?Y) = Some (x, y) -> _  |- _ ] =>
    specialize (H X Y eq_refl)

  | [ H1 : ?X = true, H2 : ?X = false |- _ ] => rewrite H1 in H2; discriminate

  end; simpl in *; try tauto.

Lemma Update_Update : forall A (addr : A) B (blk1 blk2 : B) r,
  Same (Update addr blk1 (Update addr blk2 r)) (Update addr blk1 r).
Proof.
  split; intros; repeat teardown.
  right; intuition.
  teardown.
Qed.

Global Program Instance Remove_Proper A B :
  Proper (eq ==> @Same _ _ ==> @Same _ _) (@Remove A B).
Obligation 1.
  relational.
  split; intros; repeat teardown.
    rewrite <- H0; assumption.
  rewrite H0; assumption.
Qed.

Global Program Instance Map_Proper A B :
  Proper (pointwise_relation _ (pointwise_relation _ eq)
            ==> @Same _ _ ==> @Same _ _) (@Map A B B).
Obligation 1.
  relational.
  split; intros; repeat teardown; subst;
  exists x1;
  split.
  - rewrite H; reflexivity.
  - rewrite <- H0; assumption.
  - rewrite H; reflexivity.
  - rewrite H0; assumption.
Qed.

Lemma Unique_Map_Update : forall A B (P : A -> B -> bool) a b r f,
  (forall x y : A, {x = y} + {x <> y}) ->
  Functional r ->
  Lookup a b r ->
  P a b = true ->
  Unique P a r ->
  Same (Map (fun k e => if P k e then f k e else e) r) (Update a (f a b) r).
Proof.
  intros.
  split; intros; repeat teardown; subst.
  - destruct (X a0 a) eqn:Heqe.
      subst; left.
      specialize (H _ _ H0 _ H4); subst.
      rewrite H1.
      intuition.
    right.
    eapply All_Remove_Lookup_inv in H2; eauto.
    rewrite H2.
    intuition.
  - exists b.
    rewrite H1.
    intuition.
  - exists b0.
    eapply All_Remove_Lookup_inv in H2; eauto.
    rewrite H2.
    intuition.
Qed.
