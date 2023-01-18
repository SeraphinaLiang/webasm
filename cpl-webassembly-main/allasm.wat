(module
    (func $add (export "add") (param i32 i32) (result i32) 
    ;; We have defined the function $add as private to the module. 
    ;; If we want to access this function from outside the module we need to export it.
    local.get 0 ;;Push first parameter to stack
    local.get 1 ;;Push second parameter to stack
    i32.add ;;Consume two values from the stack
            ;;Push the sum of these parameters back to the stack
    )
)
;; execute --- [$ wasmtime add.wat --invoke add 1 2]

;; Exercise Write a simple WebAssembly function calc(a, b, c, d) that returns a * b - c * d
(module
    (func $calc (export "calc") (param $a i32) (param $b i32) (param $c i32) (param $d i32) (result i32)
        local.get $a ;;stack: a
        local.get $b ;;stack: b, a
        i32.mul      ;;stack: (a*b)
        local.get $c ;;stack: c, (a*b)
        local.get $d ;;stack: d, c, (a*b)
        i32.mul      ;;stack: (c*d), (a*b)
        i32.sub      ;;stack: (a*b) - (c*d) ;; what is left on the stack is the result
    )
)

;; Recursion
(module
    (func $factorial (export "fact") (param i32) (result i32)
        ;;Function execution starts from *an empty stack*
        ;;Due to the result type, the function execution should end
        ;;with a single i32 value on the stack.
        (if (result i32) ;;Both if-branches must end with one i32 on the stack
            (i32.lt_s (local.get 0) (i32.const 2)) ;;Condition (if n < 2) 0!=1,1!=1
            (then (i32.const 1)) ;;Push value 1 to stack
            (else
                (i32.sub (local.get 0) (i32.const 1)) ;;Push value n - 1 to stack
                call $factorial ;;Pops one value (n - 1) from stack and pushes
                                ;;factorial(n - 1) to stack
                local.get 0     ;;Push n to stack
                i32.mul         ;;Pops 2 values from stack (n, n - 1)
                                ;;and replaces with their multiplication
            )
        )
    )
)
;; if the signature of a valid WebAssembly function states that it takes two parameters
;; and produces one return value, this is a guarantee. Thus, the type system knows the 
;; exact effect a function call will have on the state of the program call stack.

;;Exercise: Write a recursive function $fibonnaci(n) that calculates the n-th fibonnaci number.
;;0 1 1 2 3 5 8 ... f(n) = f(n-1)+f(n-2)
;;0 1 2 3 4 5 6
(module
    (func $fib (export "fib") (param $n i32) (result i32)
        (if (result i32)        
            (i32.le_s (local.get $n) (i32.const 1)) ;;if $n <= 1
            (then local.get $n) ;;stack: n
            (else 
                local.get $n ;;stack: n
                i32.const 1  ;;stack: 1, n
                i32.sub      ;;stack: n - 1
                call $fib    ;;stack: fib(n - 1)

                local.get $n ;;stack: n, fib(n - 1)
                i32.const 2  ;;stack: 2, n, fib(n - 1)
                i32.sub      ;;stack: n - 2, fib(n - 1)
                call $fib    ;;stack: fib(n - 2), fib(n - 1)

                i32.add      ;;stack: fib(n - 1) + fib(n - 2)
            )
        )
    )
)

;; if-statements cannot consume values from the stack, 
;; but they might produce a value of type valtype to the stack.
;; -> the following construct is impossible: 
;; error -> type mismatch: expected i32 but nothing on stack
(module
    (func $impossible (export "impossible") (param i32) (result i32)
    local.get 0 ;;push param to the call stack
    local.get 0 ;;push param to the call stack
        (if (i32.const 0) ;; false
            (then (i32.add)) ;;consume two values from call stack 
                             ;;(replace with sum)
            (else (i32.sub)) ;;consume two values from call stack 
                             ;;(replace with difference)
        )
    )
)
;; The problem is that structured instructions such as if-statements need to
;; adhere to the function type [] -> valtype. They are not allowed to consume 
;; values that were on the call stack before the invocation of the if-statement. 
;; In other words, just like with function calls, we need to execute the branches 
;; of an if-statement as if we had started from an empty stack. 

;; Loops
;; a loop block has the type [] -> [i32]
;; To loop, we need to use a branching statement like br_if before ending the loop.
;; br_if consumes the top value of the stack and branches if that value was non-zero.
;; i32.gt_s produces a 1 if a > b and a 0 otherwise
;; local.tee : sets the value of a local variable, just like local.set, 
;;             but it does not consume a value from the stack while doing so.
(module
    (func $factorial (export "fact") (param i32) (result i32)
        (local $res i32) ;;stack = <empty> ;; declare local var res
        (local.set $res (i32.const 1)) ;;stack = <empty> ;; $res = 1
        (loop $fact (result i32)
            ;;stack: <empty> (start of block)
            local.get 0     ;;stack: n
            local.get 0     ;;stack: n, n
            local.get $res  ;;stack: $res, n, n
            i32.mul         ;;stack: n * $res, n
            local.set $res  ;;stack: n  ; local.set consume a value from stack : $res = n * $res 
            i32.const 1     ;;stack: 1, n
            i32.sub         ;;stack: n - 1
            local.tee 0     ;;stack: n - 1   ; n = n - 1
            i32.const 1     ;;stack: 1, n - 1
            i32.gt_s        ;;stack: n - 1 > 1 ; if 1 then
            br_if $fact     ;;stack: <empty>   ; continue loop on (n-1)
            local.get $res  ;;stack: $res      ; else 0 then return res
            ;;stack: $res -> single i32, return type of block
        )
    )
)
;; Exercise Rewrite your fibonnaci function as an iterative function using loops.
;;   def f(n):
;;   a, b = 0, 1
;;   for i in range(0, n):
;;      a = b
;;      b = a + b
;;   return a
(module
    (func $fib (export "fib") (param $n i32) (result i32)
        (local $a i32)
        (local $b i32)
        i32.const 0  ;;stack: 0
        local.set $a ;;a = 0, stack: <empty>
        i32.const 1  ;;stack: 1
        local.set $b ;;b = 1, stack: <empty>
        (loop $fibloop
            local.get $a    ;;stack: a
            local.get $b    ;;stack: b, a
            i32.add         ;;stack: a + b
            local.get $b    ;;stack: b, a + b
            local.set $a    ;;b = a, stack: a + b
            local.set $b    ;;b = a + b, stack: <empty>

            local.get $n    ;;stack: n
            i32.const 1     ;;stack: 1, n
            i32.sub         ;;stack: n - 1
            local.tee $n    ;;n = n - 1, stack: n - 1 

            i32.const 1     ;;stack: 1, n - 1
            i32.gt_s        ;;stack: n - 1 > 1   ;; if n > 0 
            br_if $fibloop  ;;stack: <empty>     ;; then loop
        )
        local.get $b ;;stack: $b
    )
)
;; Hello world
;; It defines a region of global memory. Using the data command, the byte-representation of 
;; the string Hello, World!\n is written to this memory, starting at byte address 8. 
;; Using i32.store (i32.const 0) (i32.const 8) the value 8 is written at byte addresses 0 - 3 
;; in the defined memory (32 bit = 4 bytes). This value 8 of course represents the address 
;; in the same memory of the string Hello, World!. At address 4 in memory, the length of 
;; the string is written. The memory is thus prepared for a call to the system call fd_write 
;; defined in WASI. Since the file descriptor 1 is chosen, the string is written to the stdout.
(module
    ;; Import the required fd_write WASI function which will write the given io vectors to stdout
    ;; The function signature for fd_write is:
    ;; (File Descriptor, *iovs, iovs_len, nwritten) -> Returns number of bytes written
    (import "wasi_unstable" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
    (memory 1)
    (export "memory" (memory 0))
    ;; Write 'hello world\n' to memory at an offset of 8 bytes
    ;; Note the trailing newline which is required for the text to appear
    (data (i32.const 8) "Hello, world!\n")
    (func $main (export "_start")
        ;; Creating a new io vector within linear memory
        (i32.store (i32.const 0) (i32.const 8))  ;; iov.iov_base - This is a pointer to the start of the 'hello world\n' string
        (i32.store (i32.const 4) (i32.const 12))  ;; iov.iov_len - The length of the 'hello world\n' string
        (call $fd_write
            (i32.const 1) ;; file_descriptor - 1 for stdout
            (i32.const 0) ;; *iovs - The pointer to the iov array, which is stored at memory location 0
            (i32.const 1) ;; iovs_len - We're printing 1 string stored in an iov - so one.
            (i32.const 20) ;; nwritten - A place in memory to store the number of bytes written
        )
        drop ;; Discard the number of bytes written from the top of the stack
    )
)
;; FizzBuzz
(module
    ;; Import the required fd_write WASI function which will write the given io vectors to stdout
    ;; The function signature for fd_write is:
    ;; (File Descriptor, *iovs, iovs_len, nwritten) -> Returns number of bytes written
    (import "wasi_unstable" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
    (memory $mem 1)
    (export "memory" (memory $mem))
                                              ;; address
    (data (i32.const 8) "0")                  ;; [ 8]  0               
    (data (i32.const 10) "Fizz\n")            ;; [10]  "Fizz\n"
    (data (i32.const 15) "Buzz\n")            ;; [15]  "Buzz\n"
    (data (i32.const 20) "FizzBuzz\n")        ;; [20]  "FizzBuzz\n"

    (func $print (param $addr i32) (param $len i32)
        (i32.store (i32.const 0) (local.get $addr)) ;; address of the string
        (i32.store (i32.const 4) (local.get $len))  ;; length of the string
        (call $fd_write
            (i32.const 1)
            (i32.const 0)
            (i32.const 1)
            (i32.const 0)
        )
        drop
    )

    (func $print_fizz
        (call $print  (i32.const 10) (i32.const 5))
    )
    (func $print_buzz
        (call $print  (i32.const 15) (i32.const 5))
    )
    (func $print_fizzbuzz
        (call $print  (i32.const 20) (i32.const 9))
    )
    (func $print_char (param i32)
        (i32.store8 (i32.const 8) (local.get 0)) ;;convert to byte representation
        (call $print  (i32.const 8) (i32.const 1))
    )

;; void digit(int n)
;; {   
;;    if (n < 0)   n = -1*n;
;;    if (n/10 > 0) digit(n/10);            
;;    cout << n%10 << endl;
;;}
    (func $print_uint (param i32)
        (local $div10 i32)
        (local.set $div10 (i32.div_u (local.get 0) (i32.const 10))) ;; $div10 = n / 10
        (if
            (i32.gt_u (local.get $div10) (i32.const 0)) ;; if n/10 > 0
            (call $print_uint (local.get $div10)) ;; print (n/10)
        )
        (call $print_char (i32.add (i32.rem_u (local.get 0) (i32.const 10)) (i32.const 48))) ;; print (n%10)
    )

    (func $can_divide (param $a i32) (param $b i32) (result i32)
         local.get $a ;;stack: a
         local.get $b ;;stack: b, a
         i32.rem_s    ;;stack: a % b
         i32.const 0  ;;stack: 0, a % b
         i32.eq       ;;stack: a % b == 0
    )

    (func $fizzbuzz
        (local $i i32)
        (local $div3 i32)
        (local $div5 i32)
        (local $div3and5 i32)
        i32.const 1
        local.set $i  ;; i = 1
        (loop $fizzbuzzloop
            local.get $i        ;;stack: i
            i32.const 3         ;;stack: 3, i
            call $can_divide    ;;stack: (i % 3 == 0)
            local.tee $div3     ;;stack: (i % 3 == 0)  
            ;;  $div3 = (i % 3 == 0)
            local.get $i        ;;stack: i, (i % 3 == 0)
            i32.const 5         ;;stack: 5, i, (i % 3 == 0)
            call $can_divide    ;;stack: (i % 5 == 0), (i % 3 == 0)
            local.tee $div5     ;;stack: (i % 5 == 0), (i % 3 == 0)  
            ;;  $div5 = (i % 5 == 0)
            i32.and             ;;stack: (i % 5 == 0) & (i % 3 == 0) ;  <- binary AND
            i32.const 1         ;;stack: 1, (i % 5 == 0) & (i % 3 == 0)
            i32.eq              ;;stack: ((i % 5 == 0) & (i % 3 == 0)) == 1
            local.set $div3and5 ;;stack: <empty>  
            ;;  $div3and5 = (((i % 5 == 0) & (i % 3 == 0)) == 1)
            (if (local.get $div3and5)
                (then call $print_fizzbuzz)
                (else (if (local.get $div3)
                        (then call $print_fizz)
                        (else (if (local.get $div5)
                                (then call $print_buzz)
                                (else
                                    local.get $i
                                    call $print_uint
                                    i32.const 10
                                    call $print_char ;;print \n
                                )
                            )
                        )
                    )
                )
            )
            local.get $i ;;stack: i
            i32.const 1  ;;stack: 1, i
            i32.add    ;;stack: i + 1
            local.tee $i ;;i = i + 1, stack: i + 1 
            i32.const 100 ;;stack: 100, i + 1
            i32.le_s ;;stack: i + 1 < 100
            br_if $fizzbuzzloop
        )
    )
    (func $main (export "_start")
        (call $fizzbuzz)
    )
)

;; undefined behaviour
;; Exercise Try to come up with a program that has a different output 
;; when you compile it to WebAssembly 
#include <stdio.h>
#include <limits.h>
int main(void)
{
    int a;
    if (&a > 100000) printf("First path\n");
    else printf("Second path\n");
    return 0;
}
;; &-operator on a local variable
;; a WebAssembly compiler allocate the local variable somewhere in the heap




