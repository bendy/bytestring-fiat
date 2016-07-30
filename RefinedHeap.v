Require Import
  Here.ByteString
  Here.Heap
  Here.HeapADT
  Here.Nomega
  Here.BindDep
  Here.FunMaps
  Here.FMapExt
  Here.Same_set
  Here.LogicalRelations
  Here.Tactics
  Here.ADTInduction
  Here.TupleEnsembles.

Require Import Coq.Structures.OrderedTypeEx.

Module Import E := FunMaps N_as_OT.

Generalizable All Variables.

Section RefinedHeap.

Variable Word8 : Type.
Variable Zero : Word8.

Definition MemoryBlock := MemoryBlock Word8.
Definition HeapSpec := @HeapSpec Word8.

Section MemoryBlock.

Record MemoryBlockC := {
  memCSize : N;
  memCData : M.t Word8
}.

Definition MemoryBlock_AbsR (o : MemoryBlock) (n : MemoryBlockC) : Prop :=
  memSize o = memCSize n /\ Map_AbsR eq (memData o) (memCData n).

Definition MemoryBlock_Same (x y : MemoryBlock) : Prop :=
  memSize x = memSize y /\ Same (memData x) (memData y).

Definition MemoryBlockC_Equal (x y : MemoryBlockC) : Prop :=
  memCSize x = memCSize y /\ M.Equal (memCData x) (memCData y).

Global Program Instance MemoryBlock_AbsR_Proper :
  Proper (MemoryBlock_Same ==> MemoryBlockC_Equal ==> iff) MemoryBlock_AbsR.
Obligation 1.
  intros ??????;
  split; intros;
  split; intros;
  destruct H, H0, H1.
  - congruence.
  - split; intros.
      rewrite <- H2 in H5.
      reduction; exists cblk; subst.
      rewrite H3 in HC.
      intuition.
    rewrite <- H3 in H5.
    reduction; exists blk; subst.
    rewrite H2 in HC.
    intuition.
  - congruence.
  - split; intros.
      rewrite H2 in H5.
      reduction; exists cblk; subst.
      rewrite <- H3 in HC.
      intuition.
    rewrite H3 in H5.
    reduction; exists blk; subst.
    rewrite <- H2 in HC.
    intuition.
Qed.

(*
Program Instance MemoryBlock_AbsR_LogicalImpl m m' :
  MemoryBlock_AbsR m m'
    -> LogicalImpl MemoryBlock_AbsR MemoryBlockC_Equal m m'.
Obligation 1.
  constructor; assumption.
Defined.
Obligation 2.
  destruct H0, H1.
  split.
    congruence.
  apply F.Equal_mapsto_iff; split; intros;
  apply F.find_mapsto_iff in H4;
  apply F.find_mapsto_iff.
    reduction; subst.
    clear H2.
    reduction; subst.
    assumption.
  reduction; subst.
  clear H3.
  reduction; subst.
  assumption.
Qed.
*)

Corollary Empty_MemoryBlock_AbsR : forall n,
  MemoryBlock_AbsR {| memSize  := n; memData  := Empty |}
                   {| memCSize := n; memCData := M.empty Word8 |}.
Proof. split; trivial; simpl; intros; apply Empty_Map_AbsR. Qed.

Corollary MemoryBlock_AbsR_impl : forall s s' d d',
    s = s' -> Map_AbsR eq d d' ->
    MemoryBlock_AbsR {| memSize  := s;  memData  := d |}
                     {| memCSize := s'; memCData := d' |}.
Proof. intros; subst; split; intros; trivial. Qed.

Hint Extern 1 => apply MemoryBlock_AbsR_impl.

End MemoryBlock.

Require Import
  Fiat.ADT
  Fiat.ADTNotation
  Fiat.ADTRefinement
  Fiat.ADTRefinement.BuildADTRefinements.

Definition within_allocated_mem (n : N) :=
  fun (addr : M.key) (blk : MemoryBlockC) => addr + memCSize blk <=? n.

Lemma within_allocated_mem_Proper : forall n,
  Proper (eq ==> eq ==> eq) (within_allocated_mem n).
Proof.
  unfold Proper, respectful; intros.
  subst; reflexivity.
Qed.

Lemma within_allocated_mem_add : forall n x k e,
  within_allocated_mem n k e
    -> 0 < x
    -> within_allocated_mem (n + x) k e.
Proof.
  unfold within_allocated_mem; intros.
  undecide.
  apply Nle_add_plus; trivial.
Qed.

Lemma within_allocated_mem_at_end : forall n x d,
   within_allocated_mem (n + x) n {| memCSize := x; memCData := d |}.
Proof.
  unfold within_allocated_mem; simpl; intros.
  apply N.leb_refl.
Qed.

Hint Resolve within_allocated_mem_Proper.

Definition Heap_AbsR
           (or : { r : Rep HeapSpec
                 | fromADT HeapSpec r})
           (nr : N * M.t MemoryBlockC) : Prop :=
  Map_AbsR MemoryBlock_AbsR (` or) (snd nr) /\
  P.for_all (within_allocated_mem (fst nr)) (snd nr).

Program Definition Empty_Heap : { r : Rep HeapSpec | fromADT HeapSpec r} :=
  exist _ Empty (empty_fromADT _).
Obligation 1. reflexivity. Qed.

Lemma Empty_Heap_AbsR : Heap_AbsR Empty_Heap (0, M.empty MemoryBlockC).
Proof.
  split; simpl; intros.
    intro addr; split; intros; inv H.
  apply for_all_empty.
  intros ??????; subst; reflexivity.
Qed.

Corollary Lookup_find_block {r_o r_n} (AbsR : Heap_AbsR r_o r_n) addr' blk' :
  Lookup addr' blk' (` r_o)
    -> exists cblk',
         MemoryBlock_AbsR blk' cblk' /\ M.find addr' (snd r_n) = Some cblk'.
Proof.
  intros; destruct AbsR.
  reduction; exists cblk; tauto.
Qed.

Require Import FunctionalExtensionality.

Corollary Proper_within : forall pos,
   Proper (eq ==> eq ==> eq)
          (fun b e => Decidable_witness (P:=within b (memCSize e) pos)).
Proof. intros ???????; subst; reflexivity. Qed.

Definition withinMemBlock (pos : N) (b : N) (e : MemoryBlock) : Prop :=
  within b (memSize e) pos.

Definition withinMemBlockC (pos : N) (b : N) (e : MemoryBlockC) : bool :=
  Decidable_witness (P:=within b (memCSize e) pos).

Export LogicalRelationNotations.

Open Scope lsignature_scope.

Global Program Instance withinMemBlock_AbsR :
  withinMemBlock [R eq ===> eq ===> MemoryBlock_AbsR ===> boolR]
  withinMemBlockC.
Obligation 1.
  unfold withinMemBlock, withinMemBlockC; intros ?????????;
  split; intros; subst; simpl.
    apply within_reflect in H2.
    rewrite <- (proj1 H1).
    assumption.
  simpl in H2.
  apply within_reflect.
  rewrite (proj1 H1).
  assumption.
Qed.

Global Program Instance withinMemBlock_AbsR_applied (pos : N) :
  withinMemBlock pos [R eq ===> MemoryBlock_AbsR ===> boolR]
  withinMemBlockC pos.
Obligation 1. apply withinMemBlock_AbsR; reflexivity. Qed.

Notation "f \oo g" := (fun x y => f (g x y)) (at level 90).

Lemma withinMemAbsR : forall base blk cblk pos,
  withinMemBlock pos base blk
    -> MemoryBlock_AbsR blk cblk
    -> withinMemBlockC pos base cblk = true.
Proof.
  intros.
  unfold withinMemBlock, withinMemBlockC in *; simpl in *.
  apply within_reflect in H.
  destruct H0 as [H0 _]; rewrite <- H0.
  assumption.
Qed.

Theorem Peek_in_heap {r_o r_n} (AbsR : Heap_AbsR r_o r_n) pos :
  forall base blk',
    Lookup base blk' (` r_o)
      -> withinMemBlock pos base blk'
      -> exists cblk',
           find_if (withinMemBlockC pos) (snd r_n) = Some (base, cblk') /\
           MemoryBlock_AbsR blk' cblk'.
Proof.
  intros.
  pose proof (find_partitions_a_singleton (proj2_sig r_o) _ H H0).
  destruct AbsR; reduction.
  exists cblk; split; trivial.
  Fail apply find_if_filter.
    Fail apply Proper_within.
Abort.

Theorem Poke_in_heap {r_o r_n} (AbsR : Heap_AbsR r_o r_n) pos val :
  P.for_all (within_allocated_mem (fst r_n))
    (M.mapi
       (fun (addr : M.key) (cblk : MemoryBlockC) =>
        IfDec within addr (memCSize cblk) pos
        Then {| memCSize := memCSize cblk
              ; memCData := M.add (pos - addr) val (memCData cblk) |}
        Else cblk) (snd r_n)).
Proof.
  destruct AbsR as [_ H].
  unfold P.for_all.
  apply P.fold_rec_bis; eauto.
  intros.
  apply F.mapi_mapsto_iff in H0; do 2 destruct H0;
  simpl; intros; subst; auto.
  unfold within_allocated_mem, IfDec_Then_Else; simpl.
  eapply P.for_all_iff in H; eauto.
  unfold within_allocated_mem in H.
  destruct ((k <=? pos) && (pos <? k + memCSize x))%bool; simpl;
  rewrite H; assumption.
Qed.

Lemma Heap_AbsR_outside_mem
      {r_o r_n} (AbsR : Heap_AbsR r_o r_n)
      (d : {len : N | 0 < len}) :
  All (fun addr' blk' =>
         ~ overlaps addr' (memSize blk') (fst r_n) (` d)) (` r_o).
Proof.
  destruct AbsR; intros ???.
  apply LogicFacts.not_and_implication; intros.
  reduction.
  eapply P.for_all_iff with (k:=a) (e:=cblk) in H0; eauto.
    unfold within_allocated_mem in H0; simpl in H0.
    rewrite (proj1 HD).
    unfold not; intros.
    clear -H0 H1.
    undecide; nomega.
  apply F.find_mapsto_iff.
  assumption.
Qed.

Ltac AbsR_prep :=
  repeat
    match goal with
    | [ H : Heap_AbsR _ _ |- _ ] => unfold Heap_AbsR in H; simpl in H
    | [ |- Heap_AbsR _ _ ] => unfold Heap_AbsR; simpl
    | [ H : _ /\ _ |- _ ] => destruct H; simpl in H
    | [ |- _ /\ _ ] => split
    end; try eapply logical_prf; simpl; eauto.

Corollary eq_impl_eq : forall a b : N, a = b <-> a = b.
Proof. split; intros; assumption. Qed.
Hint Resolve eq_impl_eq.

Corollary neq_impl_neq : forall a b : N, a <> b <-> a <> b.
Proof. split; intros; assumption. Qed.
Hint Resolve neq_impl_neq.

Lemma HeapImpl : FullySharpened HeapSpec.
Proof.
  start sharpening ADT.
  eapply SharpenStep; [ apply (projT2 (@HeapSpecADT Word8)) |].

  hone representation using Heap_AbsR.

  refine method emptyS.
  {
    unfold empty.
    remove_dependency.
    simplify with monad laws.

    refine pick val (0%N, @M.empty _).
      finish honing.

    AbsR_prep.
  }

  refine method allocS.
  {
    unfold Heap_AbsR, alloc.
    remove_dependency.
    simplify with monad laws; simpl.

    refine pick val (fst r_n).
      Focus 2.
      apply Heap_AbsR_outside_mem; trivial.

    simplify with monad laws; simpl.
    refine pick val (fst r_n + proj1_sig d,
                     M.add (fst r_n)
                           {| memCSize := proj1_sig d
                            ; memCData := M.empty _ |} (snd r_n)).
      simplify with monad laws.
      finish honing.

    AbsR_prep.
  }

  refine method freeS.
  {
    unfold free.
    remove_dependency.
    simplify with monad laws; simpl.

    refine pick val (fst r_n, M.remove d (snd r_n)).
      simplify with monad laws.
      finish honing.

    AbsR_prep.
  }

  refine method reallocS.
  {
    unfold Heap_AbsR, realloc.
    remove_dependency.
    simplify with monad laws; simpl.

    admit.
  }

  refine method peekS.
  {
    unfold Heap_AbsR, peek.
    remove_dependency.
    simplify with monad laws; simpl.

    (* In a strictly evaluated environment, this is needlessly inefficient. *)
    refine pick val
      (match M.elements (P.filter (withinMemBlockC d) (snd r_n)) with
       | [ ]%list => Zero
       | ((base, cblk) :: _)%list =>
           Ifopt M.find (d - base) (memCData cblk) as v
           Then v
           Else Zero
       end).

    simplify with monad laws; simpl.
    refine pick val r_n.
      simplify with monad laws.
      finish honing.

    AbsR_prep.
    intros; subst; clear H.
    pose proof H1.
    eapply (find_partitions_a_singleton (proj2_sig r_o)) in H; eauto.
    replace (fun (a : N) (b : Heap.MemoryBlock Word8) => within a (memSize b) d)
       with (withinMemBlock d) in H; trivial.
(*
    destruct (Filter_Map_AbsR MemoryBlock_AbsR eq_impl_eq) as [Hfilter _].
    destruct withinMemBlock_AbsR as [HmemBlock _].
    specialize (Hfilter (withinMemBlock d) (withinMemBlockC d)
                        (HmemBlock d d eq_refl)
                        (` r_o) (snd r_n) (proj1 H0)); clear HmemBlock.
    rewrite H in Hfilter; clear H.
    destruct (Single_Map_AbsR MemoryBlock_AbsR eq_impl_eq) as [Hsingle _].
    destruct H0; reduction.
    specialize (Hsingle base base eq_refl blk' cblk HD).
    pose proof (Map_AbsR_impl).
    destruct (Hfilter base) as [H4 _]; clear Hfilter.
    destruct (H4 blk' (Lookup_Single _ _ _ _))
      as [cblk [H5 H6]]; clear H4.
    destruct H0; reduction; clear H H0.
    induction t using P.map_induction.
      admit.
    simplify_maps.
      rewrite H0 in H1, HC.
      repeat simplify_maps.
        clear IHt1.
        admit.
      destruct (M.elements _).
      inversion H5.
    destruct H6.
    reduction; subst.
    unfold F.eqb in *.
    destruct (F.eq_dec base k).
      inv H5.
      rewrite HC0; reflexivity.
*)
    admit.
  }

  refine method pokeS.
  {
    unfold poke.
    remove_dependency.
    simplify with monad laws; simpl.

    refine pick val
      (fst r_n,
       M.mapi (fun addr cblk =>
                 IfDec within addr (memCSize cblk) d
                 Then {| memCSize := memCSize cblk
                       ; memCData := M.add (d - addr) d0 (memCData cblk) |}
                 Else cblk) (snd r_n)).
      simplify with monad laws.
      finish honing.

    AbsR_prep.
  }

  refine method memcpyS.
  {
    unfold Heap_AbsR, memcpy.
    remove_dependency.
    simplify with monad laws; simpl.

    admit.
  }

  refine method memsetS.
  {
    unfold memset.
    remove_dependency.
    simplify with monad laws; simpl.

    admit.
  }

  finish_SharpeningADT_WithoutDelegation.
Abort.

End RefinedHeap.
