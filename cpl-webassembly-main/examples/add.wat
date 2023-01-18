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
;; $ wasmtime add.wat --invoke add 1 2