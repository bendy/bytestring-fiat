Require Import
  Coq.Lists.List
  Coq.Arith.Arith
  Coq.NArith.NArith
  Fiat.ADT
  Fiat.ADTNotation
  Fiat.ADTRefinement
  Fiat.ADTRefinement.BuildADTRefinements
  ByteString.Lib.ADTInduction
  ByteString.Lib.Nomega
  ByteString.Lib.Relations
  ByteString.Lib.Tactics
  ByteString.Lib.TupleEnsembles
  ByteString.Lib.Same_set
  ByteString.ByteString
  ByteString.Ens.BindDep
  ByteString.Ens.HeapEns
  ByteString.Ens.HeapEnsADT
  ByteString.Ens.Within.

Generalizable All Variables.

Open Scope N_scope.

Definition HSpec := projT1 HeapSpecADT.

Definition memcpy' (r : Rep HSpec) (addr : N) (addr2 : N) (len : N) :
  Comp (Rep HSpec * unit) :=
  Eval simpl in callMeth HSpec memcpyS r addr addr2 len.

Definition alloc' (r : Rep HSpec) (len : N | 0 < len) :
  Comp (Rep HSpec * N) :=
  Eval simpl in callMeth HSpec allocS r len.

Definition free' (r : Rep HSpec) (addr : N) : Comp (Rep HSpec * unit) :=
  Eval simpl in callMeth HSpec freeS r addr.

Definition peek' (r : Rep HSpec) (addr : N) :
  Comp (Rep HSpec * Word8) :=
  Eval simpl in callMeth HSpec peekS r addr.

Definition poke' (r : Rep HSpec) (addr : N) (w : Word8) :
  Comp (Rep HSpec * unit) :=
  Eval simpl in callMeth HSpec pokeS r addr w.

Record PS := makePS {
  psHeap : Rep HSpec;

  psBuffer : N;
  psBufLen : N;

  psOffset : N;
  psLength : N
}.

Definition simply_widen_region (r : PS) : PS :=
  {| psHeap   := psHeap r
   ; psBuffer := psBuffer r
   ; psBufLen := psBufLen r
   ; psOffset := psOffset r - 1
   ; psLength := psLength r + 1 |}.

Program Definition make_room_by_shifting_up (r : PS) (n : N | 0 < n) :
  (* We could be smarter by shifting the block so it sits mid-way within the
     buffer. *)
  Comp PS :=
  res <- memcpy' (psHeap r) (psBuffer r) (psBuffer r + n) (psLength r);
  ret {| psHeap   := fst res
       ; psBuffer := psBuffer r
       ; psBufLen := psBufLen r
       ; psOffset := 0
       ; psLength := psLength r + n |}.

Program Definition make_room_by_growing_buffer (r : PS) (n : N | 0 < n) :
  Comp PS :=
  (* We can make a trade-off here by allocating extra bytes in anticipation of
     future calls to [buffer_cons]. *)
  `(h, a) <- alloc' (psHeap r) (psLength r + n);
  `(h, _) <- memcpy' h (psBuffer r) (a + n) (psLength r);
  `(h, _) <- free' h (psBuffer r);
  ret {| psHeap   := h
       ; psBuffer := a
       ; psBufLen := psLength r + n
       ; psOffset := 0
       ; psLength := psLength r + n |}.
Obligation 1. nomega. Defined.

Program Definition allocate_buffer (r : Rep HSpec) (len : N | 0 < len) :
  Comp PS :=
  `(h, a) <- alloc' r len;
  ret {| psHeap   := h
       ; psBuffer := a
       ; psBufLen := len
       ; psOffset := 0
       ; psLength := len |}.

Definition poke_at_offset (r : PS) (d : Word8) : Comp PS :=
  res <- poke' (psHeap r) (psBuffer r + psOffset r) d;
  ret {| psHeap   := fst res
       ; psBuffer := psBuffer r
       ; psBufLen := psBufLen r
       ; psOffset := psOffset r
       ; psLength := psLength r |}.

(* This defines how much a buffer is grown by when more space is needed to
   [cons] on a new element. *)
Definition alloc_quantum := 1.
Arguments alloc_quantum /.

Program Definition buffer_cons (r : PS) (d : Word8) : Comp PS :=
  ps <- If 0 <? psOffset r
        Then ret (simply_widen_region r)
        Else If psLength r + alloc_quantum <=? psBufLen r
        Then make_room_by_shifting_up r alloc_quantum
        Else If 0 <? psBufLen r
        Then make_room_by_growing_buffer r alloc_quantum
        Else allocate_buffer (psHeap r) alloc_quantum;
  poke_at_offset ps d.
Obligation 1. nomega. Defined.
Obligation 2. nomega. Defined.
Obligation 3. nomega. Defined.

Definition buffer_uncons (r : PS) : Comp (PS * option Word8) :=
  If 0 <? psLength r
  Then (
    w <- peek' (psHeap r) (psBuffer r + psOffset r);
    ret ({| psHeap   := psHeap r
          ; psBuffer := psBuffer r
          ; psBufLen := psBufLen r
          ; psOffset := if psLength r =? 1
                        then 0
                        else psOffset r + 1
          ; psLength := psLength r - 1 |}, Some (snd w)))
  Else ret (r, None).

Definition ByteString_list_AbsR (or : Rep ByteStringSpec) (nr : PS) :=
  length or = N.to_nat (psLength nr) /\
  IF psBufLen nr = 0
  then psOffset nr = 0 /\ psLength nr = 0
  else
    fits (psBuffer nr) (psBufLen nr)
         (psBuffer nr + psOffset nr) (psLength nr) /\
    exists data,
      Lookup (psBuffer nr) {| memSize := psBufLen nr; memData := data |}
             (` (psHeap nr)) /\
      (forall i x, i < psLength nr
                     -> nth (N.to_nat i) or x = x
                     -> Lookup (psOffset nr + i) x data).

Ltac destruct_AbsR H :=
  let H1 := fresh "H1" in
  let H2 := fresh "H2" in
  destruct H as [H1 H2];
  let H3 := fresh "H3" in
  let H4 := fresh "H4" in
  let data := fresh "data" in
  destruct H2 as [[H [H2 H3]]|[H [H2 [data [H3 H4]]]]];
  [ rewrite ?H, ?H2 in * | ].

Ltac construct_AbsR := split; try split; simpl; try nomega.

Ltac competing_lookups R H A1 H0 A2 :=
  let Heqe := fresh "Heqe" in
  destruct (A1 =? A2) eqn:Heqe;
    [ apply Neqb_ok in Heqe; subst;
      pose proof (allocations_functional (proj2_sig R) _ _ H _ H0);
      subst; try nomega
    | apply N.eqb_neq in Heqe;
      pose proof (allocations_no_overlap (proj2_sig R) _ H _ H0 Heqe);
      try nomega ].

Ltac resolve_contention :=
  match goal with
  | [ H : All _ ?R, H0 : Lookup ?A ?B ?R |- _ ] => destruct (H A B)
  end.

Lemma KeepKeys_nothing : forall P m,
  (forall a, ~ P a) -> KeepKeys P m = Empty.
Proof.
  intros.
  apply Extensionality_Ensembles, Same_Same_set.
  split; unfold KeepKeys; intros;
  teardown; firstorder.
Qed.

Lemma KeepKeys_everything : forall (P : N -> Prop) m,
  (forall a, P a) -> KeepKeys P m = m.
Proof.
  intros.
  apply Extensionality_Ensembles, Same_Same_set.
  split; unfold KeepKeys; intros;
  teardown; firstorder.
Qed.

Lemma ShiftKeys_nothing : forall a b, ShiftKeys a b Empty = Empty.
Proof.
  intros.
  apply Extensionality_Ensembles, Same_Same_set.
  split; unfold ShiftKeys; intros;
  teardown; firstorder.
Qed.

Lemma CopyBlock_nothing : forall base1 base2 addr1 addr2 blk1 blk2 len,
  len = 0 ->
    CopyBlock blk1 (addr1 - base1) blk2 (addr2 - base2) len = memData blk2.
Proof.
  intros; subst.
  unfold CopyBlock.
  unfold not, compose.
  rewrite KeepKeys_everything; [|nomega].
  rewrite KeepKeys_nothing; [|nomega].
  rewrite ShiftKeys_nothing.
  apply Extensionality_Ensembles.
  apply Same_Same_set; split; intros.
    teardown; firstorder.
  left; assumption.
Qed.

Corollary refine_memcpy_zero heap addr1 addr2 :
  refineEquiv (memcpy heap addr1 addr2 0) (ret (heap, tt)).
Proof. reflexivity. Qed.

Lemma Map_unique_is_Update heap base blk addr len f :
  fromADT HeapSpec heap ->
  Lookup base blk heap ->
  fits base (memSize blk) addr len ->
  Unique (fun a b => fits_bool a (memSize b) addr len) base heap ->
  Same (Map (fun daddr dblk =>
               Ifdec fits daddr (memSize dblk) addr len
               Then f daddr dblk
               Else dblk) heap)
       (Update base (f base blk) heap).
Proof.
  intros; apply Unique_Map_Update; eauto.
  - apply N.eq_dec.
  - apply allocations_functional; assumption.
  - nomega.
Qed.

Lemma refine_memcpy_existing_blocks
      heap base1 base2 addr1 addr2 len blk1 blk2 :
  fromADT HeapSpec heap ->
  Lookup base1 blk1 heap ->
  fits base1 (memSize blk1) addr1 len ->
  Lookup base2 blk2 heap ->
  fits base2 (memSize blk2) addr2 len ->
  refineEquiv
    (memcpy heap addr1 addr2 len)
    (ret (Update base2
            {| memSize := memSize blk2
             ; memData :=
                 CopyBlock blk1 (addr1 - base1)
                           blk2 (addr2 - base2) len |} heap, tt)).
Proof.
  unfold memcpy, FindBlockThatFits; intro HH; intros.
  unfold Ifdec_Then_Else at 1; simpl.
  destruct (0 <? len) eqn:Heqe.
    split.
      refine pick val (Some (base1, blk1)).
        simplify with monad laws; simpl.
        apply refine_ret_ret_fst_Same; trivial.
        apply Same_Same_set.
        rewrite Map_unique_is_Update; eauto.
          reflexivity.
        eapply allocations_unique_fits; eauto.
      intuition.
    intros ??.
    destruct_computations.
    destruct x; try destruct p; simpl.
      destruct H3.
      competing_lookups (exist _ heap HH) H base1 H3 n.
      apply eq_ret_compute; f_equal.
      apply Extensionality_Ensembles, Same_Same_set.
      symmetry.
      rewrite Map_unique_is_Update;
      [|assumption|exact H1|assumption|].
        reflexivity.
      eapply allocations_unique_fits; eauto.
    clear H1.
    resolve_contention; auto; nomega.
  assert (len = 0) by nomega.
  rewrite CopyBlock_nothing; trivial.
  destruct blk2; simpl in *.
  split;
  apply refine_ret_ret_fst_Same; trivial;
  apply Same_Same_set;
  [|symmetry];
  apply Lookup_Update_idem; auto;
  try (apply allocations_functional; auto);
  intros; destruct (N.eq_dec a a'); auto.
Qed.

Lemma simply_within : forall n m A (P Q : A),
  0 < m -> Ifdec within n m n Then P Else Q = P.
Proof. intros; decisions; auto; nomega. Qed.

Corollary within_nothing : forall addr p, ~ within addr 0 p.
Proof. nomega. Qed.

Theorem buffer_cons_sound
        (r_o : list Word8) (r_n : PS)
        (AbsR : ByteString_list_AbsR r_o r_n) :
  forall x r_n' (H : buffer_cons r_n x ↝ r_n'),
    ByteString_list_AbsR (x :: r_o) r_n'.
Proof.
  unfold buffer_cons; intros.
  apply refine_computes_to_ret in H.
  rewrite refineEquiv_If_Then_Else_Bind in H.
  apply refine_If_Then_Else_bool in H.
  destruct (0 <? psOffset r_n) eqn:Heqe.
    apply refine_computes_to_ret in H.
    {
      destruct_computations; simpl.
      destruct_AbsR AbsR; construct_AbsR.
      right; intuition; [nomega|].
      exists (Update (psOffset r_n - 1) x data).
      split; intros; teardown.
        destruct_computations; tsubst; teardown.
        exists {| memSize := psBufLen r_n; memData := data |}; simpl.
        decisions; intuition.
          f_equal; f_equal; nomega.
        destruct H2; nomega.
      destruct i using N.peano_ind.
        left; nomega.
      right; split; [nomega|].
      rewrite <- N.add_sub_swap; [|nomega].
      rewrite <- N.add_sub_assoc; [|nomega].
      apply H4; [nomega|].
      rewrite N2Nat.inj_sub.
      replace (N.to_nat 1) with 1%nat; [|nomega].
      simpl; rewrite N2Nat.inj_succ in *; simpl.
      rewrite Nat.sub_0_r; assumption.
    }
  assert (psOffset r_n = 0) by nomega; clear Heqe.
  rewrite refineEquiv_If_Then_Else_Bind in H.
  apply refine_If_Then_Else_bool in H.
  destruct (psLength r_n + alloc_quantum <=? psBufLen r_n) eqn:Heqe2;
  [| rewrite refineEquiv_If_Then_Else_Bind in H;
     destruct (0 <? psBufLen r_n) eqn:Heqe3; simpl in H ];
  apply refine_computes_to_ret in H; revert H;
  unfold make_room_by_shifting_up, make_room_by_growing_buffer,
         allocate_buffer, poke_at_offset;
  autorewrite with monad laws; simpl;
  rewrite ?N.add_0_r;
  unfold memcpy', alloc', free', poke';
  rewrite refine_bind_dep_bind_ret; simpl;
  repeat setoid_rewrite refine_bind_dep_bind_ret; simpl.
  - simpl; intros; destruct_computations;
    destruct_AbsR AbsR; construct_AbsR;
    (right; split; [nomega|]; split; [nomega|]).
    rewrite H0, N.add_0_r in *; clear H0.
    destruct (psLength r_n =? 0) eqn:Heqe.
      assert (psLength r_n = 0) by nomega.
      rewrite H in *; clear H.
      apply refine_memcpy_zero in x1.
      destruct x1, x3; simpl.
      exists (Update 0 x data).
      split.
        exists {| memSize := psBufLen r_n; memData := data |}; simpl.
        split; auto.
        replace (psBuffer r_n - psBuffer r_n) with 0 by nomega.
        rewrite simply_within; auto.
        nomega.
      intros; teardown.
      destruct i using N.peano_ind.
        left; nomega.
      nomega.
    eapply refine_memcpy_existing_blocks in x1; eauto.
    + destruct x1, x3; simpl.
      remember (CopyBlock _ _ _ _ _) as C.
      exists (Update 0 x C).
      split.
        teardown.
        exists {| memSize := psBufLen r_n; memData := C |}; simpl.
        rewrite HeqC; clear HeqC.
        split.
          replace (psBuffer r_n - psBuffer r_n) with 0 by nomega.
          replace (psBuffer r_n + 1 - psBuffer r_n) with 1 by nomega.
          rewrite simply_within; nomega.
        teardown.
      rewrite HeqC; clear HeqC C.
      intros; teardown.
      destruct i using N.peano_ind.
        left; nomega.
      right; split; [nomega|]; clear IHi.
      rewrite N2Nat.inj_succ in *; simpl.
      unfold CopyBlock, KeepKeys, ShiftKeys; teardown.
      assert (i < psLength r_n) by nomega.
      right; teardown.
      exists (i, x0); simpl.
      split.
        f_equal; nomega.
      specialize (H4 _ _ H5 H0).
      teardown; intuition.
      nomega.
    + exact (proj2_sig (psHeap r_n)).
    + nomega.
  - simpl; intros;
    apply Bind_dep_inv in H;
    destruct H as [? [x1 ?]];
    assert (fromADT HeapSpec (fst x0))
      by (eapply alloc_fromADT; eauto;
          [ exact (proj2_sig (psHeap r_n))
          | simpl; apply refine_computes_to_ret; apply x1 ]).
    simpl; intros; destruct_computations;
    destruct_AbsR AbsR; construct_AbsR;
    (right; split; [nomega|]; split; [nomega|]).
    rewrite H0, N.add_0_r in *; simpl in *; clear H0.
    apply Bind_inv in x1; destruct x1 as [? [? ?]].
    apply Pick_inv in H0; simpl in *.
    destruct H5; simpl in *.
    eapply refine_memcpy_existing_blocks
      with (base1:=psBuffer r_n) (base2:=x1)
           (blk1:={| memSize := psBufLen r_n; memData := data |})
           (blk2:={| memSize := psLength r_n + 1; memData := Empty |})
        in x3; repeat teardown; eauto; try nomega.
    destruct_computations; simpl in *; tsubst.
    remember (CopyBlock _ _ _ _ _) as C.
    exists (Update 0 x C); split.
      repeat teardown.
      eexists {| memSize := psLength r_n + 1; memData := C |}.
      rewrite simply_within; simpl; [|nomega].
      replace (x1 - x1) with 0 by nomega.
      split; trivial.
      apply Lookup_Remove; [|nomega].
      teardown.
    destruct i using N.peano_ind;
    simpl in *; intros; subst; teardown.
    right; split; [nomega|].
    unfold CopyBlock, ShiftKeys, KeepKeys.
    teardown; right.
    teardown; exists (i, x0); split; simpl.
      f_equal; nomega.
    teardown.
    split; [|nomega].
    apply H4; [nomega|].
    rewrite N2Nat.inj_succ in *; simpl.
    assumption.
  - simpl; intros; destruct_computations;
    destruct_AbsR AbsR; construct_AbsR;
    (right; split; [nomega|]; split; [nomega|]).
    unfold alloc, FindFreeBlock in x1.
    destruct_computations; simpl in *.
    rewrite H3, ?N.add_0_r in *; simpl.
    repeat teardown; subst; simpl; try nomega;
    exists (Update 0 x Empty);
    split; repeat teardown;
    try exists {| memSize := 1; memData := Empty |};
    try split; repeat teardown;
    decisions; simpl; auto;
    replace (x1 - x1) with 0 by nomega; auto;
    try nomega; simpl; intros;
    try (destruct i using N.peano_ind; simpl in *; subst;
         [ teardown | nomega ]).
Qed.

Theorem buffer_uncons_sound : forall r_o r_n a,
  ByteString_list_AbsR r_o r_n
    -> buffer_uncons r_n ↝ a
    -> ByteString_list_AbsR (match r_o with
                             | [] => r_o
                             | _ :: xs => xs
                             end) (fst a).
Proof.
  unfold buffer_uncons; intros.
  apply refine_computes_to_ret in H0.
  apply refine_If_Then_Else_bool in H0.
  destruct (0 <? psLength r_n) eqn:Heqe.
    revert H0.
    unfold peek'.
    rewrite refine_bind_dep_bind_ret; simpl.
    rewrite refine_bind_dep_ignore.
    unfold peek, FindBlockThatFits.
    autorewrite with monad laws; simpl; intros.
    apply refine_computes_to_ret in H0.
    destruct_computations.
    destruct_AbsR H; construct_AbsR;
    destruct x; try destruct p; simpl in *;
    destruct r_o; simpl in *;
    try nomega; right;
    split; try nomega; split;
    destruct (psLength r_n =? 1) eqn:Heqe2;
    try nomega;
    try (eexists; split; [exact H4|]; nomega);
    (eexists;
     split; [exact H4|];
     intros;
     rewrite <- N.add_assoc;
     apply H5;
     [ apply N.lt_add_lt_sub_l
     | rewrite N.add_1_l, N2Nat.inj_succ ];
     trivial).
  apply refine_computes_to_ret in H0.
  destruct_computations.
  destruct_AbsR H; construct_AbsR;
  destruct r_o; simpl in *; auto; try nomega.
  - left; intuition.
  - right; intuition.
    eexists; intuition.
    exact H3.
Qed.

Theorem buffer_uncons_impl : forall r_o r_n a,
  ByteString_list_AbsR r_o r_n
    -> buffer_uncons r_n ↝ a
    -> snd a = match r_o with
               | [] => None
               | x :: _ => Some x
               end.
Proof.
  unfold buffer_uncons; intros.
  apply refine_computes_to_ret in H0.
  apply refine_If_Then_Else_bool in H0.
  destruct (0 <? psLength r_n) eqn:Heqe.
    revert H0.
    unfold peek'.
    rewrite refine_bind_dep_bind_ret; simpl.
    rewrite refine_bind_dep_ignore.
    unfold peek, FindBlockThatFits.
    autorewrite with monad laws; simpl; intros.
    apply refine_computes_to_ret in H0.
    destruct_computations.
    destruct_AbsR H; simpl;
    destruct r_o; simpl in *; try nomega.
    f_equal.
    destruct x; tsubst; simpl in *.
      destruct p.
      specialize (H1 w _ _ eq_refl); simpl in *.
      apply H1.
      destruct H0.
      competing_lookups (psHeap r_n) H4 (psBuffer r_n) H0 n.
      simpl in *.
      replace (psBuffer r_n + psOffset r_n - psBuffer r_n)
         with (psOffset r_n + 0) by nomega.
      apply H5; nomega.
    resolve_contention; trivial; nomega.
  apply refine_computes_to_ret in H0.
  apply Return_inv in H0.
  destruct a; tsubst; simpl in *.
  destruct r_o; simpl in *;
  destruct H, H0; auto.
    destruct H0, H1.
    rewrite H2 in H; simpl in H.
    discriminate.
  nomega.
Qed.

Section Refined.

Variable heap : Rep HSpec.

Lemma ByteStringHeap  : { adt : _ & refineADT ByteStringSpec adt }.
Proof.
  eexists.
  hone representation using ByteString_list_AbsR.
  {
    simplify with monad laws.
    refine pick val {| psHeap   := heap
                     ; psBuffer := 0
                     ; psBufLen := 0
                     ; psOffset := 0
                     ; psLength := 0 |}.
      finish honing.
    split; simpl; auto.
    left; auto.
  }
  {
    simplify with monad laws.
    etransitivity.
      eapply (refine_skip2 (dummy:=buffer_cons r_n d)).
    etransitivity.
      apply refine_under_bind; intros; simpl.
      refine pick val a.
        simplify with monad laws.
        finish honing.
      eapply buffer_cons_sound; eauto.
    unfold buffer_cons, simply_widen_region,
           make_room_by_shifting_up, make_room_by_growing_buffer.
    simplify with monad laws; simpl.
    finish honing.
  }
  {
    simplify with monad laws.
    etransitivity.
      eapply (refine_skip2 (dummy:=buffer_uncons r_n)).
    etransitivity.
      apply refine_under_bind; intros; simpl.
      pose proof H1.
      eapply buffer_uncons_impl in H1; eauto.
      rewrite fst_match_list, snd_match_list.
      setoid_rewrite <- H1.
      refine pick val (fst a).
        simplify with monad laws.
        rewrite <- surjective_pairing.
        finish honing.
      eapply buffer_uncons_sound; eauto.
    simplify with monad laws.
    unfold buffer_uncons.
    finish honing.
  }
  apply reflexivityT.
Defined.

End Refined.
