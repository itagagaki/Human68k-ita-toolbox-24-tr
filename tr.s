* tr - translate characters
*
* Itagaki Fumihiko 14-Aug-93  Create.
* 1.0
*
* Usage: tr [ -bcdsSZ ] [ -- ] [ 文字列１ [ 文字列２ ] ]
*

.include doscall.h
.include chrcode.h

.xref DecodeHUPAIR
.xref atou
.xref issjis
.xref strlen
.xref strfor1
.xref minmaxul

STACKSIZE	equ	2048

OUTBUF_SIZE	equ	8192

CTRLD	equ	$04
CTRLZ	equ	$1A

FLAG_b		equ	0	*  -b : bsd
FLAG_c		equ	1	*  -c : complement
FLAG_d		equ	2	*  -d : delete
FLAG_s		equ	3	*  -s : suppress
FLAG_S		equ	4	*  -S : SJIS
FLAG_Z		equ	5	*  -Z
buffering	equ	6
suppress	equ	7

.text

start:
		bra.s	start1
		dc.b	'#HUPAIR',0
start1:
		lea	bsstop(pc),a6			*  A6 := BSSの先頭アドレス
		lea	stack_bottom(a6),a7		*  A7 := スタックの底
		lea	$10(a0),a0			*  A0 : PDBアドレス
		move.l	a7,d0
		sub.l	a0,d0
		move.l	d0,-(a7)
		move.l	a0,-(a7)
		DOS	_SETBLOCK
		addq.l	#8,a7
	*
	*  引数並び格納エリアを確保する
	*
		lea	1(a2),a0			*  A0 := コマンドラインの文字列の先頭アドレス
		bsr	strlen				*  D0.L := コマンドラインの文字列の長さ
		addq.l	#1,d0
		bsr	malloc
		bmi	insufficient_memory

		movea.l	d0,a1				*  A1 := 引数並び格納エリアの先頭アドレス
	*
	*  引数をデコードし，解釈する
	*
		moveq	#0,d6				*  D6.W : エラー・コード
		bsr	DecodeHUPAIR			*  引数をデコードする
		movea.l	a1,a0				*  A0 : 引数ポインタ
		move.l	d0,d7				*  D7.L : 引数カウンタ
decode_opt_start:
		moveq	#0,d5				*  D5.L : フラグbits
decode_opt_loop1:
		tst.l	d7
		beq	decode_opt_done

		cmpi.b	#'-',(a0)
		bne	decode_opt_done

		tst.b	1(a0)
		beq	decode_opt_done

		subq.l	#1,d7
		addq.l	#1,a0
		move.b	(a0)+,d0
		cmp.b	#'-',d0
		bne	decode_opt_loop2

		tst.b	(a0)+
		beq	decode_opt_done

		subq.l	#1,a0
decode_opt_loop2:
		moveq	#FLAG_b,d1
		cmp.b	#'b',d0
		beq	set_option

		moveq	#FLAG_c,d1
		cmp.b	#'c',d0
		beq	set_option

		moveq	#FLAG_d,d1
		cmp.b	#'d',d0
		beq	set_option

		moveq	#FLAG_s,d1
		cmp.b	#'s',d0
		beq	set_option

		moveq	#FLAG_S,d1
		cmp.b	#'S',d0
		beq	set_option

		moveq	#FLAG_Z,d1
		cmp.b	#'Z',d0
		beq	set_option

		moveq	#1,d1
		tst.b	(a0)
		beq	bad_option_1

		bsr	issjis
		bne	bad_option_1

		moveq	#2,d1
bad_option_1:
		move.l	d1,-(a7)
		pea	-1(a0)
		move.w	#2,-(a7)
		lea	msg_illegal_option(pc),a0
		bsr	werror_myname_and_msg
		DOS	_WRITE
		lea	10(a7),a7
usage:
		lea	msg_usage(pc),a0
		bra	werror_exit_1

set_option:
		bset	d1,d5
set_option_done:
		move.b	(a0)+,d0
		bne	decode_opt_loop2
		bra	decode_opt_loop1

decode_opt_done:
		lea	str_nul(pc),a1
		move.l	a1,strdesc1+scanptr(a6)
		move.l	a1,strdesc2+scanptr(a6)
		subq.l	#1,d7
		blo	args_ok

		move.l	a0,strdesc1+scanptr(a6)
		bsr	strfor1
		subq.l	#1,d7
		blo	args_ok

		move.l	a0,strdesc2+scanptr(a6)
args_ok:
	*
	*  表を作る
	*
		clr.b	strdesc1+stat(a6)
		clr.b	strdesc2+stat(a6)

		lea	table2(a6),a0
		bsr	clear_table

		lea	table1(a6),a0
		lea	table2(a6),a2
		btst	#FLAG_c,d5
		bne	make_table_c

		btst	#FLAG_d,d5
		bne	make_delete_table

		move.w	#255,d0
initialize_translate_table_loop:
		move.b	d0,(a0,d0.w)
		dbra	d0,initialize_translate_table_loop
make_translate_table_loop:
		lea	strdesc1(a6),a1
		bsr	scan1char
		bmi	make_table1_done

		move.w	d0,d1
		lea	strdesc2(a6),a1
		bsr	scan1char
		smi	d2
		bpl	make_translate_table_1

		btst	#FLAG_b,d5
		bne	make_translate_table_2

		move.b	d1,d0
		bra	make_translate_table_2

make_translate_table_1:
		st	(a2,d0.w)
make_translate_table_2:
		move.b	d0,(a0,d1.w)
		tst.b	strdesc1+stat(a6)
		bpl	make_translate_table_loop

		tst.b	d2
		bne	make_table1_done

		tst.b	strdesc2+stat(a6)
		bpl	make_translate_table_loop

		move.l	strdesc1+counter(a6),d0
		move.l	strdesc2+counter(a6),d1
		bsr	minmaxul
		sub.l	d0,strdesc1+counter(a6)
		sub.l	d0,strdesc2+counter(a6)
		bra	make_translate_table_loop
****
make_table_c:
		bsr	make_table1_boolean
		move.w	#255,d1
		btst	#FLAG_d,d5
		bne	make_table_cd

		lea	strdesc2(a6),a1
make_table_c_loop:
		tst.b	(a0)
		bne	make_table_c_1

		bsr	scan1char
		bpl	make_table_c_2

		btst	#FLAG_b,d5
		bne	make_table_c_3
make_table_c_1:
		move.b	#255,d0
		sub.b	d1,d0
		bra	make_table_c_3

make_table_c_2:
		st	(a2,d0.w)
make_table_c_3:
		move.b	d0,(a0)+
		dbra	d1,make_table_c_loop

		bra	make_table1_done
		****
make_table_cd:
make_table_cd_loop:
		not.b	(a0)+
		dbra	d1,make_table_cd_loop

		bra	make_table1_done
****
make_delete_table:
		bsr	make_table1_boolean
make_table1_done:
		btst	#FLAG_s,d5
		beq	make_table2_done

		movea.l	a2,a0
		lea	strdesc2(a6),a1
		bsr	make_table_boolean
make_table2_done:
		bclr	#buffering,d5
		moveq	#1,d0				*  出力は
		bsr	is_chrdev			*  キャラクタ・デバイスか？
		bne	outbuf_ok

		bset	#buffering,d5

		*  出力バッファを確保
		move.l	#OUTBUF_SIZE,d0
		move.l	d0,d4				*  D4 : outbufカウンタ
		bsr	malloc
		bmi	insufficient_memory

		move.l	d0,outbuf_top(a6)
		move.l	d0,a4				*  A4 : outbufポインタ
outbuf_ok:
		*  入力バッファを確保
		move.l	#$00ffffff,d0
		move.l	d0,inpbuf_size(a6)
		bsr	malloc
		bpl	inpbuf_ok

		sub.l	#$81000000,d0
		move.l	d0,inpbuf_size(a6)
		bsr	malloc
		bmi	insufficient_memory
inpbuf_ok:
		move.l	d0,inpbuf_top(a6)
	*
	*  標準入力を切り替える
	*
		clr.w	-(a7)				*  標準入力を
		DOS	_DUP				*  複製したハンドルから入力し，
		addq.l	#2,a7
		tst.l	d0
		bmi	open_file_failure

		move.w	d0,stdin(a6)
		clr.w	-(a7)
		DOS	_CLOSE				*  標準入力はクローズする．
		addq.l	#2,a7				*  こうしないと ^C や ^S が効かない
	*
	*  開始
	*
		move.w	stdin(a6),d2
		bsr	tr_one
		clr.w	-(a7)				*  標準入力を
		move.w	stdin(a6),-(a7)			*  元に
		DOS	_DUP2				*  戻す．
		DOS	_CLOSE				*  複製はクローズする．
exit_program:
		move.w	d6,-(a7)
		DOS	_EXIT2

open_file_failure:
		lea	msg_no_file_handle(pc),a0
		bra	werror_exit_3
****************************************************************
bad_string:
		bsr	werror_myname
		lea	msg_bad_string(pc),a0
werror_exit_1:
		bsr	werror
		moveq	#1,d6
		bra	exit_program
****************************************************************
clear_table:
		move.w	#255,d0
clear_table_loop:
		sf	(a0,d0.w)
		dbra	d0,clear_table_loop
make_table_boolean_return:
		rts
****************************************************************
make_table1_boolean:
		bsr	clear_table
		lea	strdesc1(a6),a1
make_table_boolean:
make_table_boolean_loop:
		clr.l	counter(a1)
		bsr	scan1char
		bmi	make_table_boolean_return

		st	(a0,d0.w)
		bra	make_table_boolean_loop
****************************************************************
scan1char:
		movem.l	d1-d2/a0,-(a7)
		movea.l	scanptr(a1),a0
		moveq	#0,d0
		move.b	currchar(a1),d0
		tst.b	stat(a1)
		beq	scan1char_not_inc_nor_rep
		bmi	scan1char_rep

		cmp.b	endchar(a1),d0
		bhs	scan1char_break_inc_or_rep

		addq.b	#1,d0
		move.b	d0,currchar(a1)
		bra	scan1char_ok

scan1char_rep:
		subq.l	#1,counter(a1)
		bcc	scan1char_ok
scan1char_break_inc_or_rep:
		clr.b	stat(a1)
scan1char_not_inc_nor_rep:
		btst	#FLAG_b,d5
		bne	scan1char_bsd

		cmpi.b	#'[',(a0)
		bne	scan1char_normal

		addq.l	#1,a0
		bsr	scan1char_1
		bmi	bad_string

		move.b	d0,currchar(a1)
		move.b	(a0)+,d0
		cmp.b	#'*',d0
		beq	scan1char_begin_rep

		cmp.b	#'-',d0
		bne	bad_string

		move.b	#1,stat(a1)
		bsr	scan1char_1
		bmi	bad_string

		cmp.b	currchar(a1),d0
		blo	bad_string

		move.b	d0,endchar(a1)
		bra	scan1char_bracket_done

scan1char_begin_rep:
		move.b	#$ff,stat(a1)
		bsr	tr_atou
		neg.l	d0
		bmi	bad_string			*  overflow

		move.l	#9999,counter(a1)
		subq.l	#1,d1
		bcs	scan1char_bracket_done

		move.l	d1,counter(a1)
scan1char_bracket_done:
		move.b	currchar(a1),d0
		cmpi.b	#']',(a0)+
		bne	bad_string
scan1char_ok:
		moveq	#0,d1
		bra	scan1char_done

scan1char_normal:
		bsr	scan1char_1
scan1char_done:
		move.l	a0,scanptr(a1)
		tst.w	d1
		movem.l	(a7)+,d1-d2/a0
		rts

scan1char_bsd:
		bsr	scan1char_1
		bmi	scan1char_bsd_ok1

		move.b	d0,currchar(a1)
		cmpi.b	#'-',(a0)
		bne	scan1char_bsd_ok1

		move.l	a2,-(a7)
		movea.l	a0,a2
		addq.l	#1,a0
		bsr	scan1char_1
		bmi	scan1char_bsd_ok2

		cmp.b	currchar(a1),d0
		blo	scan1char_bsd_ok2

		move.b	d0,endchar(a1)
		move.b	#1,stat(a1)
		movea.l	a0,a2
scan1char_bsd_ok2:
		movea.l	a2,a0
		movea.l	(a7)+,a2
scan1char_bsd_ok1:
		move.b	currchar(a1),d0
		bra	scan1char_done
****************
scan1char_1:
		move.b	(a0)+,d0
		beq	scan1char_1_eos

		cmp.b	#'\',d0
		bne	scan1char_1_ok

		move.b	(a0)+,d0
		beq	scan1char_1_eos

		cmp.b	#'0',d0
		blo	scan1char_1_ok

		cmp.b	#'7',d0
		bhi	scan1char_1_ok

		sub.b	#'0',d0
		moveq	#2,d2
		bra	scan1char_octal_start

scan1char_octal_continue:
		move.b	(a0),d1
		sub.b	#'0',d1
		blo	scan1char_1_ok

		cmp.b	#7,d1
		bhi	scan1char_1_ok

		addq.l	#1,a0
		lsl.b	#3,d0
		or.b	d1,d0
scan1char_octal_start:
		dbra	d2,scan1char_octal_continue
scan1char_1_ok:
		moveq	#0,d1
		rts

scan1char_1_eos:
		subq.l	#1,a0
		moveq	#-1,d1
		rts
****************************************************************
tr_atou:
		cmpi.b	#'0',(a0)
		bne	atou

		moveq	#0,d0
		moveq	#0,d1
scan_octal_loop:
		move.b	(a0),d0
		sub.b	#'0',d0
		blo	scan_octal_done

		cmp.b	#7,d0
		bhi	scan_octal_done

		lsl.l	#1,d1
		bcs	bad_string

		lsl.l	#1,d1
		bcs	bad_string

		lsl.l	#1,d1
		bcs	bad_string

		add.l	d0,d1
		addq.l	#1,a0
		bra	scan_octal_loop

scan_octal_done:
		moveq	#0,d0
		rts
****************************************************************
* tr_one
****************************************************************
tr_one:
		btst	#FLAG_Z,d5
		sne	terminate_by_ctrlz(a6)
		sf	terminate_by_ctrld(a6)
		move.w	d2,d0
		bsr	is_chrdev
		beq	tr_one_start			*  -- ブロック・デバイス

		btst	#5,d0				*  '0':cooked  '1':raw
		bne	tr_one_start

		st	terminate_by_ctrlz(a6)
		st	terminate_by_ctrld(a6)
tr_one_start:
		sf	sjis(a6)
		bclr	#suppress,d5
		lea	table1(a6),a5			*  A5 : 表の先頭アドレス
tr_one_loop1:
		move.l	inpbuf_size(a6),-(a7)
		move.l	inpbuf_top(a6),-(a7)
		move.w	d2,-(a7)
		DOS	_READ
		lea	10(a7),a7
		move.l	d0,d3
		bmi	read_fail
		beq	tr_one_done

		movea.l	inpbuf_top(a6),a3
tr_one_loop2:
		moveq	#0,d0
		move.b	(a3)+,d0
		cmp.b	#CTRLZ,d0
		bne	tr_one_not_ctrlz

		tst.b	terminate_by_ctrlz(a6)
		bne	tr_one_done
		bra	tr_one_not_eof
tr_one_not_ctrlz:
		cmp.b	#CTRLD,d0
		bne	tr_one_not_eof

		tst.b	terminate_by_ctrld(a6)
		bne	tr_one_done
tr_one_not_eof:
		btst	#FLAG_S,d5
		beq	tr_one_gosling

		not.b	sjis(a6)
		beq	write_one

		bsr	issjis
		beq	write_one

		not.b	sjis(a6)
tr_one_gosling:
		btst	#FLAG_d,d5
		beq	tr_one_tr

		tst.b	(a5,d0.w)
		beq	write_one
		bra	putc_done

tr_one_tr:
		move.b	(a5,d0.w),d0
write_one:
		btst	#suppress,d5
		beq	write_one_1

		cmp.b	suppress_char(a6),d0
		beq	putc_done

		bclr	#suppress,d5
write_one_1:
		btst	#FLAG_s,d5
		beq	write_one_2

		lea	table2(a6),a0
		tst.b	(a0,d0.w)
		beq	write_one_2

		bset	#suppress,d5
		move.b	d0,suppress_char(a6)
write_one_2:
		btst	#buffering,d5
		bne	putc_buffering

		move.b	d0,one_char_buffer(a6)
		move.l	#1,-(a7)
		pea	one_char_buffer(a6)
		move.w	#1,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		cmp.l	#1,d0
		bne	write_fail
		bra	putc_done

putc_buffering:
		tst.l	d4
		bne	putc_buffering_1

		bsr	flush_outbuf
putc_buffering_1:
		move.b	d0,(a4)+
		subq.l	#1,d4
putc_done:
		subq.l	#1,d3
		bne	tr_one_loop2
		bra	tr_one_loop1

tr_one_done:
flush_outbuf:
		move.l	d0,-(a7)
		btst	#buffering,d5
		beq	flush_return

		move.l	#OUTBUF_SIZE,d0
		sub.l	d4,d0
		beq	flush_return

		move.l	d0,-(a7)
		move.l	outbuf_top(a6),-(a7)
		move.w	#1,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		tst.l	d0
		bmi	write_fail

		cmp.l	-4(a7),d0
		blo	write_fail

		movea.l	outbuf_top(a6),a4
		move.l	#OUTBUF_SIZE,d4
flush_return:
		move.l	(a7)+,d0
		rts
*****************************************************************
insufficient_memory:
		lea	msg_no_memory(pc),a0
		bra	werror_exit_3
*****************************************************************
read_fail:
		lea	msg_read_fail(pc),a0
		bra	werror_exit_3
*****************************************************************
write_fail:
		lea	msg_write_fail(pc),a0
werror_exit_3:
		bsr	werror_myname_and_msg
		moveq	#3,d6
		bra	exit_program
*****************************************************************
werror_myname:
		move.l	a0,-(a7)
		lea	msg_myname(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
		rts
*****************************************************************
werror_myname_and_msg:
		bsr	werror_myname
werror:
		movem.l	d0/a1,-(a7)
		movea.l	a0,a1
werror_1:
		tst.b	(a1)+
		bne	werror_1

		subq.l	#1,a1
		suba.l	a0,a1
		move.l	a1,-(a7)
		move.l	a0,-(a7)
		move.w	#2,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		movem.l	(a7)+,d0/a1
		rts
*****************************************************************
is_chrdev:
		move.w	d0,-(a7)
		clr.w	-(a7)
		DOS	_IOCTRL
		addq.l	#4,a7
		tst.l	d0
		bpl	is_chrdev_1

		moveq	#0,d0
is_chrdev_1:
		btst	#7,d0
		rts
*****************************************************************
malloc:
		move.l	d0,-(a7)
		DOS	_MALLOC
		addq.l	#4,a7
		tst.l	d0
		rts
*****************************************************************
.data

	dc.b	0
	dc.b	'## tr 1.0 ##  Copyright(C)1993 by Itagaki Fumihiko',0

msg_myname:		dc.b	'tr: ',0
msg_no_memory:		dc.b	'メモリが足りません',CR,LF,0
msg_no_file_handle:	dc.b	'ファイル・ハンドルが足りません',CR,LF,0
msg_read_fail:		dc.b	'入力エラー',CR,LF,0
msg_write_fail:		dc.b	'出力エラー',CR,LF,0
msg_illegal_option:	dc.b	'不正なオプション -- ',0
msg_bad_string:		dc.b	'文字列が不正です',CR,LF,0
msg_usage:		dc.b	CR,LF,'使用法:  tr [-b] [-SZ] [-cds] [--] [string1 [string2]]',CR,LF
str_nul:		dc.b	0
*****************************************************************
.offset 0
scanptr:		ds.l	1
counter:		ds.l	1
stat:			ds.b	1
currchar:		ds.b	1
endchar:		ds.b	1
.even
strdesc_size:

.bss
.even
bsstop:
.offset 0
outbuf_top:		ds.l	1
inpbuf_top:		ds.l	1
inpbuf_size:		ds.l	1
stdin:			ds.w	1
strdesc1:		ds.b	strdesc_size
strdesc2:		ds.b	strdesc_size
table1:			ds.b	256
table2:			ds.b	256
terminate_by_ctrlz:	ds.b	1
terminate_by_ctrld:	ds.b	1
sjis:			ds.b	1
suppress_char:		ds.b	1
one_char_buffer:	ds.b	1

		ds.b	STACKSIZE
.even
stack_bottom:
*****************************************************************

.end start
