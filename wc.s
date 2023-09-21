* wc - count characters, words and lines of file
*
* Itagaki Fumihiko 26-Jan-93  Create.
* 1.0
*
* Usage: wc [ -lwcCZ ] [ -- ] [ <ファイル> | - ] ...

.include doscall.h
.include chrcode.h

.xref DecodeHUPAIR
.xref issjis
.xref isspace
.xref strlen
.xref strfor1
.xref utoa
.xref printfi
.xref strip_excessive_slashes

STACKSIZE	equ	2048

FLAG_l		equ	0
FLAG_w		equ	1
FLAG_c		equ	2
FLAG_C		equ	3
FLAG_Z		equ	4

CTRLD	equ	$04
CTRLZ	equ	$1A

.text

start:
		bra	start1
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
		bsr	DecodeHUPAIR			*  引数をデコードする
		movea.l	a1,a0				*  A0 : 引数ポインタ
		move.l	d0,d7				*  D7.L : 引数カウンタ
		moveq	#0,d5				*  D5.L : フラグ
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
		moveq	#FLAG_Z,d1
		cmp.b	#'Z',d0
		beq	set_option

		moveq	#FLAG_l,d1
		cmp.b	#'l',d0
		beq	set_option

		moveq	#FLAG_w,d1
		cmp.b	#'w',d0
		beq	set_option

		moveq	#FLAG_c,d1
		cmp.b	#'c',d0
		beq	set_option

		moveq	#FLAG_C,d1
		cmp.b	#'C',d0
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
		lea	msg_usage(pc),a0
		bsr	werror
		moveq	#1,d6
		bra	exit_program

set_option:
		bset	d1,d5
		move.b	(a0)+,d0
		bne	decode_opt_loop2
		bra	decode_opt_loop1

decode_opt_done:
		move.b	d5,d0
		and.b	#15,d0				*  -lwcC
		bne	option_ok

		or.b	#7,d5				*  -lwc
option_ok:
	*
	*  入力バッファを確保する
	*
		move.l	#$00ffffff,d0
		bsr	malloc
		sub.l	#$81000000,d0
		move.l	d0,inpbuf_size(a6)
		bsr	malloc
		bmi	insufficient_memory

		move.l	d0,inpbuf_top(a6)
	*
	*  開始
	*
		moveq	#0,d6				*  D6.W : エラー・コード
		tst.l	d7
		bne	for_file_start

		lea	str_nul(pc),a5
		bsr	do_stdin
		bra	for_file_done

for_file_start:
		subq.l	#1,d7
		shi	print_total(a6)
		clr.l	total_lines(a6)
		clr.l	total_words(a6)
		clr.l	total_characters(a6)
		clr.l	total_C_characters(a6)
for_file_loop:
		movea.l	a0,a1
		bsr	strfor1
		exg	a0,a1
		cmpi.b	#'-',(a0)
		bne	for_file_open

		tst.b	1(a0)
		bne	for_file_open

		movea.l	a0,a5
		bsr	do_stdin
		bra	for_file_continue

for_file_open:
		bsr	strip_excessive_slashes
		clr.w	-(a7)
		move.l	a0,-(a7)
		DOS	_OPEN
		addq.l	#6,a7
		tst.l	d0
		bpl	open_file_ok

		bsr	werror_myname
		bsr	werror
		lea	msg_open_fail(pc),a0
		bsr	werror
		moveq	#2,d6
		bra	for_file_continue

open_file_ok:
		move.w	d0,d2
		movea.l	a0,a4
		movea.l	a0,a5
		bsr	do_file
		move.w	d2,-(a7)
		DOS	_CLOSE
		addq.l	#2,a7
for_file_continue:
		movea.l	a1,a0
		subq.l	#1,d7
		bcc	for_file_loop

		tst.b	print_total(a6)
		beq	for_file_done

		move.l	total_lines(a6),d0
		move.l	d0,lines(a6)
		move.l	total_words(a6),d0
		move.l	d0,words(a6)
		move.l	total_characters(a6),d0
		move.l	d0,characters(a6)
		move.l	total_C_characters(a6),d0
		move.l	d0,C_characters(a6)
		lea	word_total(pc),a5
		bsr	do_print
for_file_done:
exit_program:
		move.w	d6,-(a7)
		DOS	_EXIT2
****************************************************************
* do_stdin
* do_file
****************************************************************
do_stdin:
		moveq	#0,d2
		lea	str_stdin(pc),a4
do_file:
		movem.l	d1/d3-d4/a0-a2,-(a7)
		btst	#FLAG_Z,d5
		sne	terminate_by_ctrlz(a6)
		sf	terminate_by_ctrld(a6)
		move.w	d2,-(a7)
		clr.w	-(a7)
		DOS	_IOCTRL
		addq.l	#4,a7
		btst	#7,d0				*  '0':block  '1':character
		beq	do_file_start

		btst	#5,d0				*  '0':cooked  '1':raw
		bne	do_file_start

		st	terminate_by_ctrlz(a6)
		st	terminate_by_ctrld(a6)
do_file_start:
		clr.l	lines(a6)
		clr.l	words(a6)
		clr.l	characters(a6)
		clr.l	C_characters(a6)
		st	lastchar_is_space(a6)
		sf	lastchar_is_cr(a6)
		movea.l	inpbuf_top(a6),a1
do_file_loop:
		move.l	inpbuf_size(a6),-(a7)
		move.l	a1,-(a7)
		move.w	d2,-(a7)
		DOS	_READ
		lea	10(a7),a7
		move.l	d0,d3
		bmi	do_file_read_fail
.if 0
		beq	do_file_done	* （ここで終わらなくても下で終わってくれる）
.endif

		sf	d4				* D4.B : EOF flag
		tst.b	terminate_by_ctrlz(a6)
		beq	trunc_ctrlz_done

		moveq	#CTRLZ,d0
		bsr	trunc
trunc_ctrlz_done:
		tst.b	terminate_by_ctrld(a6)
		beq	trunc_ctrld_done

		moveq	#CTRLD,d0
		bsr	trunc
trunc_ctrld_done:
		tst.l	d3
		beq	do_file_done

		movea.l	a1,a2
count_loop:
		move.b	(a2)+,d0
		*
		*  count characters
		*
		addq.l	#1,characters(a6)
		addq.l	#1,C_characters(a6)
		*
		*  count words
		*
		bsr	isspace
		seq	d1				*  D1 : current char is space
		tst.b	lastchar_is_space(a6)
		beq	not_newword

		tst.b	d1
		bne	not_newword

		addq.l	#1,words(a6)
not_newword:
		move.b	d1,lastchar_is_space(a6)
		*
		*  count lines
		*
		cmp.b	#LF,d0
		bne	count_continue

		addq.l	#1,lines(a6)
		tst.b	lastchar_is_cr(a6)
		beq	count_continue

		subq.l	#1,C_characters(a6)
count_continue:
		cmp.b	#CR,d0
		seq	lastchar_is_cr(a6)
		subq.l	#1,d3
		bne	count_loop

		tst.b	d4
		beq	do_file_loop
do_file_done:
		bsr	do_print
		move.l	lines(a6),d0
		add.l	d0,total_lines(a6)
		move.l	words(a6),d0
		add.l	d0,total_words(a6)
		move.l	characters(a6),d0
		add.l	d0,total_characters(a6)
		move.l	C_characters(a6),d0
		add.l	d0,total_C_characters(a6)
do_file_return:
		movem.l	(a7)+,d1/d3-d4/a0-a2
		rts

do_file_read_fail:
		bsr	werror_myname
		movea.l	a4,a0
		bsr	werror
		lea	msg_read_fail(pc),a0
		bsr	werror
		moveq	#2,d6
		bra	do_file_return
*****************************************************************
trunc:
		move.l	d3,d1
		beq	trunc_done

		movea.l	a1,a2
trunc_find_loop:
		cmp.b	(a2)+,d0
		beq	trunc_found

		subq.l	#1,d1
		bne	trunc_find_loop
		bra	trunc_done

trunc_found:
		move.l	a2,d3
		subq.l	#1,d3
		sub.l	a1,d3
		st	d4
trunc_done:
		rts
*****************************************************************
do_print:
		movem.l	d1-d4/a0-a2,-(a7)
		moveq	#0,d1
		moveq	#' ',d2
		moveq	#10,d3
		moveq	#1,d4
		lea	utoa(pc),a0
		lea	putc(pc),a1
		suba.l	a2,a2
		btst	#FLAG_l,d5
		beq	not_print_lines

		move.l	lines(a6),d0
		bsr	printu
not_print_lines:
		btst	#FLAG_w,d5
		beq	not_print_words

		move.l	words(a6),d0
		bsr	printu
not_print_words:
		btst	#FLAG_c,d5
		beq	not_print_characters

		move.l	characters(a6),d0
		bsr	printu
not_print_characters:
		btst	#FLAG_C,d5
		beq	not_print_C_characters

		move.l	C_characters(a6),d0
		bsr	printu
not_print_C_characters:
		tst.b	(a5)
		beq	print_done

		bsr	put_space
		bsr	put_space
		move.l	a5,-(a7)
		DOS	_PRINT
		addq.l	#4,a7
print_done:
		movem.l	(a7)+,d1-d4/a0-a2
		moveq	#CR,d0
		bsr	putc
		moveq	#LF,d0
		bra	putc
*****************************************************************
put_space:
		moveq	#' ',d0
putc:
		movem.l	d0,-(a7)
		move.w	d0,-(a7)
		DOS	_PUTCHAR
		addq.l	#2,a7
		movem.l	(a7)+,d0
		rts
*****************************************************************
printu:
		move.l	d0,-(a7)
		bsr	put_space
		move.l	(a7)+,d0
		bra	printfi
*****************************************************************
malloc:
		move.l	d0,-(a7)
		DOS	_MALLOC
		addq.l	#4,a7
		tst.l	d0
		rts
*****************************************************************
insufficient_memory:
		lea	msg_no_memory(pc),a0
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
.data

	dc.b	0
	dc.b	'## wc 1.0 ##  Copyright(C)1993 by Itagaki Fumihiko',0

msg_myname:		dc.b	'wc: ',0
msg_no_memory:		dc.b	'メモリが足りません',CR,LF,0
msg_open_fail:		dc.b	': オープンできません',CR,LF,0
msg_read_fail:		dc.b	': 入力エラー',CR,LF,0
msg_illegal_option:	dc.b	'不正なオプション -- ',0
msg_usage:		dc.b	CR,LF,'使用法:  wc [-lwcCZ] [--] [<ファイル>] ...',CR,LF,0
word_total:		dc.b	'合計',0
str_stdin:		dc.b	'-'
str_nul:		dc.b	0
*****************************************************************
.bss
.even
bsstop:
.offset 0
inpbuf_top:		ds.l	1
inpbuf_size:		ds.l	1
lines:			ds.l	1
words:			ds.l	1
characters:		ds.l	1
C_characters:		ds.l	1
total_lines:		ds.l	1
total_words:		ds.l	1
total_characters:	ds.l	1
total_C_characters:	ds.l	1
terminate_by_ctrlz:	ds.b	1
terminate_by_ctrld:	ds.b	1
lastchar_is_space:	ds.b	1
lastchar_is_cr:		ds.b	1
print_total:		ds.b	1

		ds.b	STACKSIZE
.even
stack_bottom:
*****************************************************************

.end start
