" A plugin aimed to correct vim indentation

" Setup
setlocal autoindent
setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/
setlocal cinoptions=(0,u0,U0,g0,:0,t0

nnoremap <silent> <F7> :set operatorfunc=ReindentOperator<CR>g@
vnoremap <silent> <F7> :<C-U>call ReindentOperator(visualmode())<CR>

imap <Leader><Tab> <Esc>:call ReindentLine(line('.'))<CR>i
nmap <Leader><Tab> :call ReindentLine(line('.'))<CR>

inoremap <buffer><script> <CR> <CR><Esc>:call ReindentLine(line('.'))<CR>^I
nnoremap <buffer><script> o o<Esc>:call ReindentLine(line('.'))<CR>A
nnoremap <buffer><script> O O<Esc>:call ReindentLine(line('.'))<CR>A

nmap <F6> :call ReindentFile()<CR>
imap <F6> <Esc>:call ReindentFile()<CR>i

" Only define the function once.
if exists("*ReindentLine")
	finish
endif

function! s:CountOcurrences(pattern, line)
	let counter = 0
	let pos = match(a:line, a:pattern, 0)
	while pos != -1
		let counter += 1
		let pos = match(a:line, a:pattern, pos+1)
	endwhile
	return counter
endfunction

function! s:HasUnclosedParenthesis(line)
	let withoutStrings = substitute(a:line, '"[^"]*"', '', 'g')

	let openPattern = '('
	let closePattern = ')'
	let openCount = s:CountOcurrences(openPattern, withoutStrings)
	let closeCount = s:CountOcurrences(closePattern, withoutStrings)
	return openCount > closeCount
endfunction

function! s:IsMiddleOfComment(line)
	return a:line =~ '^\s*\*\( .*\)*$'
endfunction

function! s:IsEndOfComment(line)
	return a:line =~ '^\s*\*/'
endfunction

function! s:IsNewBlock(line)
	return a:line =~ '{\s*$'
endfunction

function! s:AlignmentNeeded(current, previous)
	return s:HasUnclosedParenthesis(a:previous) || s:IsMiddleOfComment(a:current) || s:IsEndOfComment(a:current)
endfunction

function! s:FindNumberOfSpacesNeeded(currentLineNumber, previousLineNumber)
	let indentationGuess = cindent(a:currentLineNumber)
	let previousGuess = cindent(a:previousLineNumber)
	return indentationGuess - previousGuess
endfunction

function! s:GetPreviousLineIndentString(previousLine)
	return matchstr(a:previousLine, '^\s*')
endfunction

function! s:GuessTabsForLine(line)
	return cindent(a:line)/&ts
endfunction

function! s:GetTabsNumber(line)
	return strlen(matchstr(a:line, '^\t*'))
endfunction

function! s:IndentDifference(currentLineNumber, previousLineNumber)
	let currentLineTabs = s:GuessTabsForLine(a:currentLineNumber)
	let previousLineTabs = s:GuessTabsForLine(a:previousLineNumber)
	return currentLineTabs - previousLineTabs
endfunction

" The function that actually reindent a line
function! ReindentLine(currentLineNumber)
	if a:currentLineNumber == 1
		return
	endif

	" Cleaning up previous line
	if getline(a:currentLineNumber - 1) =~ '^\s*$'
		execute (a:currentLineNumber-1) . 's/\s*//g'
	endif

	let previousLineNumber = prevnonblank(a:currentLineNumber - 1)

	let indentDifference = s:IndentDifference(a:currentLineNumber, previousLineNumber)
	if indentDifference < 0
		let lineTabs = s:GuessTabsForLine(a:currentLineNumber)
		let indentString = repeat('\t', lineTabs)
		execute a:currentLineNumber . 's/^\s*/' . indentString . '/'
		return
	endif

	let previousLine = getline(previousLineNumber)
	let currentLine = getline(a:currentLineNumber)
	let previousLineIndentString = s:GetPreviousLineIndentString(previousLine)
	let tabsNumberCurrent = s:GetTabsNumber(currentLine)
	let tabsNumberPrevious = s:GetTabsNumber(previousLine)

	if s:AlignmentNeeded(currentLine, previousLine)
		let spacesNumber = s:FindNumberOfSpacesNeeded(a:currentLineNumber, previousLineNumber)
		let indentString = previousLineIndentString . repeat(' ', spacesNumber)
	elseif s:IsEndOfComment(previousLine)
		let lastSpaceRemoved = strpart(previousLineIndentString, 0, len(previousLineIndentString) - 1)
		let indentString = lastSpaceRemoved
	elseif s:IsNewBlock(previousLine) && tabsNumberCurrent > tabsNumberPrevious
		let indentString = repeat('\t', tabsNumberPrevious + 1)
	else
		let indentString = previousLineIndentString . repeat('\t', indentDifference)
	endif

	execute a:currentLineNumber . 's/^\s*/' . indentString . '/'
endfunction

" Defines a new operator function, to be called for the '=' operator
function! ReindentOperator(type)
	if a:type ==# 'v' || a:type ==# 'char' || a:type == 'line'
		call ReindentLine(line('.'))
	else
		if a:type ==# 'block'
			let startLineNumber = line("'[")
			let endLineNumber = line("']")
		else
			let startLineNumber = line("'<")
			let endLineNumber = line("'>")
		endif

		startLineNumber,endLineNumber call ReindentLine(line('.'))
	endif
endfunction

function! ReindentFile()
	let currentLine = line('.')
	%call ReindentLine(line('.'))
	exe currentLine
endfunction
