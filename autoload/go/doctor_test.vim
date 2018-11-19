func! Test_Extract() abort
  try
    let l:original = [
          \ 'package main',
          \ '',
          \ 'import "fmt"',
          \ '',
          \ 'func main() {',
          \ "\t" . 'msg := "I am a little teapot"',
          \ "\t" . 'fmt.Println(msg)',
          \ "\t" . 'msg += ", short and stout"',
          \ '',
          \ "\t" . 'fmt.Println(msg)',
          \ '}']
    let l:dir = gotest#write_file('extract/extract.go', l:original)

    call cursor(10, 1)
    silent execute "normal m<"
    call cursor(line('.'), col('$'))
    silent execute "normal m>"
    call go#doctor#Extract(1, 'printmsg')

    let l:expected = [
          \ 'package main',
          \ '',
          \ 'import "fmt"',
          \ '',
          \ 'func main() {',
          \ "\t" . 'msg := "I am a little teapot"',
          \ "\t" . 'fmt.Println(msg)',
          \ "\t" . 'msg += ", short and stout"',
          \ '',
          \ "\t" . 'printmsg(msg)',
          \ '}',
          \ 'func printmsg(msg string) {',
          \ "\t" . 'fmt.Println(msg)',
          \ '}']

    let l:actual = go#util#GetLines()
    let l:start = reltime()
    while l:original == l:actual && reltimefloat(reltime(start)) < 10
      sleep 100m
      let l:actual = go#util#GetLines()
    endwhile

    call assert_equal(l:expected, l:actual)
  finally
    call delete(l:dir, 'rf')
  endtry
endfunc

" vim:ts=2:sw=2:et
