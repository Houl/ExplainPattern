" File:         explainpat.vim
" Created:      2011 Nov 02
" Last Change:  2013 Dec 30
" Rev Days:     12
" Author:	Andy Wokula <anwoku@yahoo.de>
" License:	Vim License, see :h license
" Version:	0.7

" Implements :ExplainPattern [pattern]

" History: "{{{
" 2013 Jun 21	AND/OR text is confusing, removed
" 2013 Apr 20	...
"}}}

" TODO {{{
" - add something like "(empty) ... match everywhere" ... example: '\v(&&|str)'
"   Pattern: \v(&&|str)
"   Magic Pattern: \(\&\&\|str\)
"     \(         start of first capturing group
"     |                  (empty) match everywhere
"     |   \&         AND
"     |                  (empty) match everywhere
"     |   \&         AND
"     |                  (empty) match everywhere
"     | \|         OR
"     |   str        literal string (3 atom(s))
"     \)         end of group
" - more testing, completeness check
" ? detailed collections
" ? literal string: also print the unescaped magic items
" ? literal string: show leading/trailing spaces
"
"}}}

" Init Folklore {{{
let s:cpo_save = &cpo
set cpo&vim
let g:explainpat#loaded = 1
"}}}

func! explainpat#ExplainPattern(cmd_arg, ...) "{{{
    " {a:1}	alternative help printer object (caution, no sanity check)
    "		(for test running)
    if a:cmd_arg == ""
	" let pattern_str = nwo#vis#Get()
	echo "(usage) :ExplainPattern [{register} | {pattern}]"
	return
    elseif strlen(a:cmd_arg) == 1 && a:cmd_arg =~ '["@0-9a-z\-:.*+/]'
	echo 'Register:' a:cmd_arg
	let pattern_str = getreg(a:cmd_arg)
    else
	let pattern_str = a:cmd_arg
    endif

    echo printf('Pattern: %s', pattern_str)
    let magicpat = nwo#magic#MakeMagic(pattern_str)
    if magicpat !=# pattern_str
	echo printf('Magic Pattern: %s', magicpat)
    endif

    " we need state:
    " set flag when in `\%[ ... ]' (optionally matched atoms):
    let s:in_opt_atoms = 0
    " counter for `\(':
    let s:capture_group_nr = 0
    " >=1 at pos 0 or after '\|', '\&', '\(', '\%(' or '\n'; else 0 or less:
    let s:at_begin_of_pat = 1

    let hulit = a:0>=1 && type(a:1)==s:DICT ? a:1 : s:NewHelpPrinter()
    call hulit.AddIndent('  ')
    let bull = s:NewTokenBiter(magicpat)
    while !bull.AtEnd()
	let item = bull.Bite(s:magic_item_pattern)
	if item != ''
	    let Doc = get(s:doc, item, '')
	    if empty(Doc)
		call hulit.AddLiteral(item)
	    elseif type(Doc) == s:STRING
		call hulit.Print(item, Doc)
	    elseif type(Doc) == s:FUNCREF
		call call(Doc, [bull, hulit, item])
	    elseif type(Doc) == s:LIST
		call call(Doc[0], [bull, hulit, item, Doc[1]])
	    endif
	    let s:at_begin_of_pat -= 1
	else
	    echoerr printf('ExplainPattern: cannot parse "%s"', bull.Rest())
	    break
	endif
	unlet Doc
    endwhile
    call hulit.FlushLiterals()
endfunc "}}}

" s: types {{{
let s:STRING = type("")
let s:DICT   = type({})
let s:FUNCREF = type(function("tr"))
let s:LIST = type([])
" }}}

let s:magic_item_pattern = '\C^\%(\\\%(@<\|%#=\|%[dxouU[(^$V#<>]\=\|z[1-9se(]\|@[>=!]\|_[[^$.]\=\|.\)\|.\)'

let s:doc = {} " {{{
" this is all the help data ...
"   strings, funcrefs and intermixed s:DocFoo() functions
" strongly depends on s:magic_item_pattern

func! s:DocOrBranch(bull, hulit, item) "{{{
    call a:hulit.RemIndent()
    call a:hulit.Print(a:item, "OR")
    call a:hulit.AddIndent('  ')
    let s:at_begin_of_pat = 2
endfunc "}}}

let s:doc['\|'] = function("s:DocOrBranch")

func! s:DocBeginOfPat(bull, hulit, item, msg) "{{{
    call a:hulit.Print(a:item, a:msg)
    let s:at_begin_of_pat = 2
endfunc "}}}

let s:doc['\&'] = [function("s:DocBeginOfPat"), "AND"]

let s:ord = split('n first second third fourth fifth sixth seventh eighth ninth')

func! s:DocGroupStart(bull, hulit, item) "{{{
    if a:item == '\%('
	call a:hulit.Print(a:item, "start of non-capturing group")
    elseif a:item == '\('
	let s:capture_group_nr += 1
	call a:hulit.Print(a:item, printf("start of %s capturing group", get(s:ord, s:capture_group_nr, '(invalid)')))
    else " a:item == '\z('
	call a:hulit.Print(a:item, 'start of "external" group (only usable in :syn-region)')
    endif
    call a:hulit.AddIndent('| ', '  ')
    let s:at_begin_of_pat = 2
endfunc "}}}
func! s:DocGroupEnd(bull, hulit, item) "{{{
    call a:hulit.RemIndent(2)
    call a:hulit.Print(a:item, "end of group")
endfunc "}}}

let s:doc['\('] = function("s:DocGroupStart")
let s:doc['\%('] = function("s:DocGroupStart")
let s:doc['\)'] =  function("s:DocGroupEnd")
" let s:doc['\z('] = "only in syntax scripts"
let s:doc['\z('] = function("s:DocGroupStart")

func! s:DocStar(bull, hulit, item) "{{{
    if s:at_begin_of_pat >= 1
	" call a:hulit.Print(a:item, "(at begin of pattern) literal `*'")
	call a:hulit.AddLiteral(a:item)
    else
	call a:hulit.Print(a:item, "(multi) zero or more of the preceding atom")
    endif
endfunc "}}}

" let s:doc['*'] = "(multi) zero or more of the preceding atom"
let s:doc['*'] = function("s:DocStar")

let s:doc['\+'] = "(multi) one or more of the preceding atom"
let s:doc['\='] = "(multi) zero or one of the preceding atom"
let s:doc['\?'] = "(multi) zero or one of the preceding atom"
" let s:doc['\{'] = "(multi) N to M, greedy"
" let s:doc['\{-'] = "(multi) N to M, non-greedy"

func! s:DocBraceMulti(bull, hulit, item) "{{{
    let rest = a:bull.Bite('^-\=\d*\%(,\d*\)\=}')
    if rest != ""
	if rest == '-}'
	    call a:hulit.Print(a:item. rest, "non-greedy version of `*'")
	elseif rest =~ '^-'
	    call a:hulit.Print(a:item. rest, "(multi) N to M, non-greedy")
	else
	    call a:hulit.Print(a:item. rest, "(multi) N to M, greedy")
	endif
    else
	call a:hulit.Print(a:item, "(invalid) incomplete `\\{...}' item")
    endif
endfunc "}}}

let s:doc['\{'] = function("s:DocBraceMulti")

let s:doc['\@>'] = "(multi) match preceding atom like a full pattern"
let s:doc['\@='] = "(assertion) require match for preceding atom"
let s:doc['\@!'] = "(assertion) forbid match for preceding atom"

func! s:DocBefore(bull, hulit, item) "{{{
    let rest = a:bull.Bite('^[=!]')
    if rest == "="
	call a:hulit.Print(a:item.rest, "(assertion) require match for preceding atom to the left")
    elseif rest == "!"
	call a:hulit.Print(a:item.rest, "(assertion) forbid match for preceding atom to the left")
    else
	call a:hulit.Print(a:item.rest, "(invalid) `\\@<' must be followed by `=' or `!'")
    endif
endfunc "}}}

let s:doc['\@<'] = function("s:DocBefore")

func! s:DocCircumFlex(bull, hulit, item) "{{{
    if s:at_begin_of_pat >= 1
	call a:hulit.Print(a:item, "(assertion) require match at start of line")
	" after `^' is not at begin of pattern ... handle special case `^*' here:
	if a:bull.Bite('^\*') == "*"
	    call a:hulit.AddLiteral("*")
	endif
    else
	" call a:hulit.Print(a:item, "(not at begin of pattern) literal `^'")
	call a:hulit.AddLiteral(a:item)
    endif
endfunc "}}}

" let s:doc['^'] = "(assertion) require match at start of line"
let s:doc['^'] = function("s:DocCircumFlex")

let s:doc['\_^'] = "(assertion) like `^', allowed anywhere in the pattern"

func! s:DocDollar(bull, hulit, item) "{{{
    if a:bull.Rest() =~ '^$\|^\\[&|)n]'
	call a:hulit.Print(a:item, "(assertion) require match at end of line")
    else
	call a:hulit.AddLiteral(a:item)
    endif
endfunc "}}}

" let s:doc['$'] = "(assertion) require match at end of line"
let s:doc['$'] = function("s:DocDollar")

let s:doc['\_$'] = "(assertion) like `$', allowed anywhere in the pattern"
let s:doc['.'] = "match any character"
let s:doc['\_.'] = "match any character or newline"

func! s:DocUnderscore(bull, hulit, item) "{{{
    let cclass = a:bull.Bite('^\a')
    if cclass != ''
	let cclass_doc = get(s:doc, '\'. cclass, '(invalid character class)')
	call a:hulit.Print(a:item. cclass, printf('%s or end-of-line', cclass_doc))
    else
	call a:hulit.Print(a:item, "(invalid) `\\_' should be followed by a letter or `[...]'")
	" echoerr printf('ExplainPattern: cannot parse %s', a:item. matchstr(a:bull.Rest(), '.'))
    endif
endfunc "}}}

let s:doc['\_'] = function("s:DocUnderscore")
let s:doc['\<'] = "(assertion) require match at begin of word, :h word"
let s:doc['\>'] = "(assertion) require match at end of word, :h word"
let s:doc['\zs'] = "set begin of match here"
let s:doc['\ze'] = "set end of match here"
let s:doc['\%^'] = "(assertion) match at begin of buffer"
let s:doc['\%$'] = "(assertion) match at end of buffer"
let s:doc['\%V'] = "(assertion) match within the Visual area"
let s:doc['\%#'] = "(assertion) match with cursor position"

func! s:DocRegexEngine(bull, hulit, item) "{{{
    let engine = a:bull.Bite('^[012]')
    if engine == "0"
	call a:hulit.Print(a:item.engine, 'Force automatic selection of the regexp engine (since v7.3.970).')
    elseif engine == "1" 
	call a:hulit.Print(a:item.engine, 'Force using the old engine (since v7.3.970).')
    elseif engine == "2"
	call a:hulit.Print(a:item.engine, 'Force using the NFA engine (since v7.3.970).')
    else
	call a:hulit.Print(a:item, '(invalid) \%#= can only be followed by 0, 1, or 2')
    endif
endfunc "}}}

let s:doc['\%#='] = function("s:DocRegexEngine")

" \%'m   \%<'m   \%>'m
" \%23l  \%<23l  \%>23l
" \%23c  \%<23c  \%>23c
" \%23v  \%<23v  \%>23v
" backslash percent at/before/after
func! s:DocBspercAt(bull, hulit, item) "{{{
    let rest = a:bull.Bite('^\%(''.\|\d\+[lvc]\)\C')
    if rest[0] == "'"
	call a:hulit.Print(a:item.rest, "(assertion) match with position of mark ". rest[1])
    else
	let number = rest[:-2]
	let type = rest[-1:]
	if type ==# "l"
	    call a:hulit.Print(a:item.rest, "match in line ". number)
	elseif type ==# "c"
	    call a:hulit.Print(a:item.rest, "match in column ". number)
	elseif type ==# "v"
	    call a:hulit.Print(a:item.rest, "match in virtual column ". number)
	else
	    call a:hulit.Print(a:item.rest, "(invalid) incomplete `\\%' item")
	    " echoerr printf('ExplainPattern: incomplete item %s', a:item. rest)
	endif
    endif
endfunc "}}}
func! s:DocBspercBefore(bull, hulit, item) "{{{
    let rest = a:bull.Bite('^\%(''.\|\d\+[lvc]\)\C')
    if rest[0] == "'"
	call a:hulit.Print(a:item.rest, "(assertion) match before position of mark ". rest[1])
    else
	let number = rest[:-2]
	let type = rest[-1:]
	if type ==# "l"
	    call a:hulit.Print(a:item.rest, printf("match above line %d (towards start of buffer)", number))
	elseif type ==# "c"
	    call a:hulit.Print(a:item.rest, "match before column ". number)
	elseif type ==# "v"
	    call a:hulit.Print(a:item.rest, "match before virtual column ". number)
	else
	    call a:hulit.Print(a:item.rest, "(invalid) incomplete `\\%<' item")
	    " echoerr printf('ExplainPattern: incomplete item %s', a:item. rest)
	endif
    endif
endfunc "}}}
func! s:DocBspercAfter(bull, hulit, item) "{{{
    let rest = a:bull.Bite('^\%(''.\|\d\+[lvc]\)\C')
    if rest[0] == "'"
	call a:hulit.Print(a:item.rest, "(assertion) match after position of mark ". rest[1])
    else
	let number = rest[:-2]
	let type = rest[-1:]
	if type ==# "l"
	    call a:hulit.Print(a:item.rest, printf("match below line %d (towards end of buffer)", number))
	elseif type ==# "c"
	    call a:hulit.Print(a:item.rest, "match after column ". number)
	elseif type ==# "v"
	    call a:hulit.Print(a:item.rest, "match after virtual column ". number)
	else
	    call a:hulit.Print(a:item.rest, "(invalid) incomplete `\\%>' item")
	    " echoerr printf('ExplainPattern: incomplete item %s', a:item. rest)
	endif
    endif
endfunc "}}}

let s:doc['\%'] = function("s:DocBspercAt")
let s:doc['\%<'] = function("s:DocBspercBefore")
let s:doc['\%>'] = function("s:DocBspercAfter")

let s:doc['\i'] = "identifier character (see 'isident' option)"
let s:doc['\I'] = "like \"\\i\", but excluding digits"
let s:doc['\k'] = "keyword character (see 'iskeyword' option)"
let s:doc['\K'] = "like \"\\k\", but excluding digits"
let s:doc['\f'] = "file name character (see 'isfname' option)"
let s:doc['\F'] = "like \"\\f\", but excluding digits"
let s:doc['\p'] = "printable character (see 'isprint' option)"
let s:doc['\P'] = "like \"\\p\", but excluding digits"
let s:doc['\s'] = "whitespace character: <Space> and <Tab>"
let s:doc['\S'] = "non-whitespace character; opposite of \\s"
let s:doc['\d'] = "digit: [0-9]"
let s:doc['\D'] = "non-digit: [^0-9]"
let s:doc['\x'] = "hex digit: [0-9A-Fa-f]"
let s:doc['\X'] = "non-hex digit: [^0-9A-Fa-f]"
let s:doc['\o'] = "octal digit: [0-7]"
let s:doc['\O'] = "non-octal digit: [^0-7]"
let s:doc['\w'] = "word character: [0-9A-Za-z_]"
let s:doc['\W'] = "non-word character: [^0-9A-Za-z_]"
let s:doc['\h'] = "head of word character: [A-Za-z_]"
let s:doc['\H'] = "non-head of word character: [^A-Za-z_]"
let s:doc['\a'] = "alphabetic character: [A-Za-z]"
let s:doc['\A'] = "non-alphabetic character: [^A-Za-z]"
let s:doc['\l'] = "lowercase character: [a-z]"
let s:doc['\L'] = "non-lowercase character: [^a-z]"
let s:doc['\u'] = "uppercase character: [A-Z]"
let s:doc['\U'] = "non-uppercase character: [^A-Z]"

let s:doc['\e'] = "match <Esc>"
let s:doc['\t'] = "match <Tab>"
let s:doc['\r'] = "match <CR>"
let s:doc['\b'] = "match CTRL-H"
let s:doc['\n'] = [function("s:DocBeginOfPat"), "match a newline"]
let s:doc['~'] = "match the last given substitute string"
let s:doc['\1'] = "match first captured string"
let s:doc['\2'] = "match second captured string"
let s:doc['\3'] = "match third captured string"
let s:doc['\4'] = "match fourth captured string "
let s:doc['\5'] = "match fifth captured string"
let s:doc['\6'] = "match sixth captured string"
let s:doc['\7'] = "match seventh captured string"
let s:doc['\8'] = "match eighth captured string"
let s:doc['\9'] = "match ninth captured string"

let s:doc['\z1'] = 'match same string matched by first "external" group'
let s:doc['\z2'] = 'match same string matched by second "external" group'
let s:doc['\z3'] = 'match same string matched by third "external" group'
let s:doc['\z4'] = 'match same string matched by fourth "external" group '
let s:doc['\z5'] = 'match same string matched by fifth "external" group'
let s:doc['\z6'] = 'match same string matched by sixth "external" group'
let s:doc['\z7'] = 'match same string matched by seventh "external" group'
let s:doc['\z8'] = 'match same string matched by eighth "external" group'
let s:doc['\z9'] = 'match same string matched by ninth "external" group'

" from MakeMagic()
" skip the rest of a collection
let s:coll_skip_pat = '^\^\=]\=\%(\%(\\[\^\]\-\\bertn]\|\[:\w\+:]\|\[=.=]\|\[\..\.]\|[^\]]\)\@>\)*]'

func! s:DocCollection(bull, hulit, item) "{{{
    let collstr = a:bull.Bite(s:coll_skip_pat)
    if collstr == "" || collstr == "]"
	call a:hulit.AddLiteral('['. collstr)
    else
	let inverse = collstr =~ '^\^'
	let with_nl = a:item == '\_['
	let descr = inverse ? printf('collection not matching [%s', collstr[1:]) : 'collection'
	let descr_nl = printf("%s%s", (inverse && with_nl ? ', but' : ''), (with_nl ? ' with end-of-line added' : ''))
	call a:hulit.Print(a:item. collstr, descr. descr_nl)
    endif
endfunc "}}}

let s:doc['['] = function("s:DocCollection")
let s:doc['\_['] = function("s:DocCollection")

func! s:DocOptAtoms(bull, hulit, item) "{{{
    if a:item == '\%['
	call a:hulit.Print(a:item, "start a sequence of optionally matched atoms")
	let s:in_opt_atoms = 1
	call a:hulit.AddIndent('. ')
    else " a:item == ']'
	if s:in_opt_atoms
	    call a:hulit.RemIndent()
	    call a:hulit.Print(a:item, "end of optionally matched atoms")
	    let s:in_opt_atoms = 0
	else
	    call a:hulit.AddLiteral(a:item)
	endif
    endif
endfunc "}}}

" let s:doc['\%['] = "start a sequence of optionally matched atoms"
let s:doc['\%['] = function("s:DocOptAtoms")
let s:doc[']'] = function("s:DocOptAtoms")

func! s:DocAnywhere(bull, hulit, item, msg) "{{{
    call a:hulit.Print(a:item, a:msg)
    " keep state:
    let s:at_begin_of_pat += 1
endfunc "}}}

let s:doc['\c'] = [function("s:DocAnywhere"), "ignore case while matching the pattern"]
let s:doc['\C'] = [function("s:DocAnywhere"), "match case while matching the pattern"]
let s:doc['\Z'] = [function("s:DocAnywhere"), "ignore composing characters in the pattern"]

" \%d 123
" \%x 2a
" \%o 0377
" \%u 20AC
" \%U 1234abcd

func! s:DocBspercDecimal(bull, hulit, item) "{{{
    let number = a:bull.Bite('^\d\{,3}')
    let char = strtrans(nr2char(str2nr(number)))
    call a:hulit.Print(a:item. number, printf("match character specified by decimal number %s (%s)", number, char))
endfunc "}}}
func! s:DocBspercHexTwo(bull, hulit, item) "{{{
    let number = a:bull.Bite('^\x\{,2}')
    let char = strtrans(nr2char(str2nr(number,16)))
    call a:hulit.Print(a:item. number, printf("match character specified with hex number 0x%s (%s)", number, char))
endfunc "}}}
func! s:DocBspercOctal(bull, hulit, item) "{{{
    let number = a:bull.Bite('^\o\{,4}')
    let char = strtrans(nr2char(str2nr(number,8)))
    call a:hulit.Print(a:item. number, printf("match character specified with octal number 0%s (%s)", substitute(number, '^0*', '', ''), char))
endfunc "}}}
func! s:DocBspercHexFour(bull, hulit, item) "{{{
    let number = a:bull.Bite('^\x\{,4}')
    let char = has("multi_byte_encoding") ? ' ('. strtrans(nr2char(str2nr(number,16))).')' : ''
    call a:hulit.Print(a:item. number, printf("match character specified with hex number 0x%s%s", number, char))
endfunc "}}}
func! s:DocBspercHexEight(bull, hulit, item) "{{{
    let number = a:bull.Bite('^\x\{,8}')
    let char = has("multi_byte_encoding") ? ' ('. strtrans(nr2char(str2nr(number,16))).')' : ''
    call a:hulit.Print(a:item. number, printf("match character specified with hex number 0x%s%s", number, char))
endfunc "}}}

let s:doc['\%d'] = function("s:DocBspercDecimal") " 123
let s:doc['\%x'] = function("s:DocBspercHexTwo") " 2a
let s:doc['\%o'] = function("s:DocBspercOctal") " 0377
let s:doc['\%u'] = function("s:DocBspercHexFour") " 20AC
let s:doc['\%U'] = function("s:DocBspercHexEight") " 1234abcd

" \m
" \M
" \v
" \V
"}}}

func! s:NewHelpPrinter() "{{{
    let obj = {}
    let obj.literals = ''
    let obj.indents = []
    let obj.len = 0	    " can be negative (!)

    func! obj.Print(str, ...) "{{{
	call self.FlushLiterals()
	let indstr = join(self.indents, '')
	echohl Comment
	echo indstr
	echohl None
	if a:0 == 0
	    echon a:str
	else
	    " echo indstr. printf("`%s'   %s", a:str, a:1)
	    echohl PreProc
	    echon printf("%-10s", a:str)
	    echohl None
	    echohl Comment
	    echon printf(" %s", a:1)
	    echohl None
	endif
    endfunc "}}}

    func! obj.AddLiteral(item) "{{{
	let self.literals .= a:item
    endfunc "}}}

    func! obj.FlushLiterals() "{{{
	if self.literals == ''
	    return
	endif
	let indstr = join(self.indents, '')
	echohl Comment
	echo indstr
	echohl None
	if self.literals =~ '^\s\|\s$'
	    echon printf("%-10s", '"'. self.literals. '"')
	else
	    echon printf("%-10s", self.literals)
	endif
	echohl Comment
	echon " literal string"
	if exists("*strchars")
	    if self.literals =~ '\\'
		let self.literals = substitute(self.literals, '\\\(.\)', '\1', 'g')
	    endif
	    let spconly = self.literals =~ '[^ ]' ? '' : ', spaces only'
	    let nlit = strchars(self.literals)
	    echon " (". nlit. (nlit==1 ? " atom" : " atoms"). spconly.")"
	endif
	echohl None
	let self.literals = ''
    endfunc  "}}}

    func! obj.AddIndent(...) "{{{
	call self.FlushLiterals()
	if self.len >= 0
	    call extend(self.indents, copy(a:000))
	elseif self.len + a:0 >= 1
	    call extend(self.indents, a:000[-(self.len+a:0):])
	endif
	let self.len += a:0
    endfunc "}}}

    func! obj.RemIndent(...) "{{{
	call self.FlushLiterals()
	if a:0 == 0
	    if self.len >= 1
		call remove(self.indents, -1)
	    endif
	    let self.len -= 1
	else
	    if self.len > a:1
		call remove(self.indents, -a:1, -1)
	    elseif self.len >= 1
		call remove(self.indents, 0, -1)
	    endif
	    let self.len -= a:1
	endif
    endfunc "}}}

    return obj
endfunc "}}}

func! s:NewTokenBiter(str) "{{{
    " {str}	string to eat pieces from
    let obj = {'str': a:str}

    " consume piece from start of input matching {pat}
    func! obj.Bite(pat) "{{{
	" {pat}	    should start with '^'
	let bite = matchstr(self.str, a:pat)
	let self.str = strpart(self.str, strlen(bite))
	return bite
    endfunc "}}}

    " get the unparsed rest of input (not consuming)
    func! obj.Rest() "{{{
	return self.str
    endfunc "}}}

    " check if end of input reached
    func! obj.AtEnd() "{{{
	return self.str == ""
    endfunc "}}}

    return obj
endfunc "}}}

" Modeline: {{{1
let &cpo = s:cpo_save
unlet s:cpo_save
" vim:ts=8:fdm=marker:
