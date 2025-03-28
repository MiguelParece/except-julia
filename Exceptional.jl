import Base.identity
struct SignalException <: Exception 
    exception::Exception
    must_handle::Bool

end

struct EndOfLine <: Exception end
struct ExitException <: Exception 
    
    token::Any
    value::Any
end

struct DivisionByZero <: Exception end


const HANDLERS_KEY = :__exceptional_handlers
const RESTARTS_KEY = :__exceptional_restarts



function error(exception)
    #verificar se existem handlers disponiveis
    #se existirem, chamar o handler
    handlers = get(task_local_storage(), HANDLERS_KEY, Pair{Type{<:Exception}, Function}[])
    handled = false
    
    for (name, handler) in reverse(handlers)
        
        if exception == name # encontrou um handler para a excepcao
            println("Handler found, calling handler")
            
            return handler(exception)
            handled = true
            break
        end
    end
    #se nao dar barraca
    if !handled
        throw(exception)
    end
end


function signal(exception)
    #verificar se existem handlers disponiveis
    #se existirem, chamar o handler
    handlers = get(task_local_storage(), HANDLERS_KEY, Pair{Type{<:Exception}, Function}[])
    handled = false


    for (name, handler) in reverse(handlers)
        
        if name == exception # encontrou um handler para a excepcao
           # println("Handler found, calling handler")
            handler(exception)
            handled = true
            break
        end
    end

    if !handled
        #println("No Handler found, ignore signal")
        # nao tem problema, nao ha handlers para esta excepcao ( signal )
    end

end


function handling(f, handlers) # funcao F e pairs de handlers
    #preparar os handlers
    current_handlers = get!(task_local_storage(), HANDLERS_KEY, Pair{Type{<:Exception}, Function}[])
    orignal_size = length(current_handlers)

    for (exception, handler) in handlers
        println("Adding handler for exception: ", exception)
        push!(current_handlers, (exception => handler))
    end
    try
        f()
    finally
        task_local_storage()[HANDLERS_KEY] = current_handlers[1:orignal_size] 
    end
end


function to_escape(f)
    token = gensym() #gerar um token unico para saber em que scope deve "escape to"
    
    function exit(value)
        throw(ExitException(token,value))
    end
    
    try
        f(exit)
    catch e
        if e isa ExitException
            if e.token == token
                return e.value
            else
                rethrow(e)
            end
        else
            rethrow(e)
        end
        
    end
end


function with_restart(f, restarts)
    return to_escape() do exit
        #preparar os restarts 
        current_restarts = get!(task_local_storage(), RESTARTS_KEY, Pair{Symbol, Function}[])
        orignal_size = length(current_restarts)

        for (restart, handler) in restarts
            push!(current_restarts, (restart => (args...) -> exit(handler(args...))))
        end
        try
            f()
        finally
            task_local_storage()[RESTARTS_KEY] = current_restarts[1:orignal_size] 
        end
    end
    
end


function available_restart(name)
    restarts = get(task_local_storage(), RESTARTS_KEY, Pair{Symbol, Function}[])
    for (restart, handler) in restarts
        if restart == name
            return true
        end
    end
    return false
end


function invoke_restart(name)
    restarts = get(task_local_storage(), RESTARTS_KEY, Pair{Symbol, Function}[])
    for (restart, handler) in restarts
        if restart == name
            println("Invoking restart: ", name)
            return handler()
            
        end
    end
    println("Restart not found")
    return false #nao encontrou nenhum restart com esse nome
end

function invoke_restart(name, args...)
    restarts = get(task_local_storage(), RESTARTS_KEY, Pair{Symbol, Function}[])
    for (restart, handler) in Iterators.reverse(restarts)
        if restart == name
            println("Invoking restart: ", name)
            return handler(args...)
            
        end
    end
    println("Restart not found")
    return false #nao encontrou nenhum restart com esse nome
end










# tests

function reciprocal(x)
    if x == 0
        signal(DivisionByZero)  # Use `throw` instead of `error`
    else
        x = 1 / x
        return x +1
    end
end



reciprocal(0)


handling([DivisionByZero => c -> println("I saw a division by zero")]) do
    reciprocal(0)
end


handling([DivisionByZero => (c) -> println("I saw a division by zero ola")]) do
    handling([DivisionByZero => (c) -> (println("i saw a div 0"))]) do
        handling([DivisionByZero => (c) -> (println("i saw a div 30"))]) do
            handling([DivisionByZero => (c) -> (println("i saw a div 350"))]) do
                reciprocal(0)
            end
            reciprocal(0)
        end
        handling([DivisionByZero => (c) -> (println("i saw a div 320"))]) do
            reciprocal(0)
        end

        reciprocal(0)
    end
    reciprocal(0)
end 



to_escape() do exit
    handling([DivisionByZero => (c) -> println("I saw a division by zero ola")]) do
        handling([DivisionByZero => (c) -> (println("i saw a div 0"); exit(5))]) do
            reciprocal(0)
        end
    end 
end



function mystery(n) 
1 +
    to_escape() do outer
        1 +
        to_escape() do inner
            1+
            if n == 0
                outer(1)
                inner(1)
            elseif n == 1
                outer(1)
            else
                1
            end
        end
    end
end



function print_line(str, line_end=20)
    let col = 0
        for c in str
            print(c)
            col += 1
            if col == line_end
                signal(EndOfLine)
                col = 0
            end
        end
    end
end

print_line("Hi, everybody! How are you feeling today?")


handling([(EndOfLine, c -> println("\n"))]) do 
    print_line("Hi, everybody! How are you feeling today?")
    
end

# print the task task_local_storage
println(task_local_storage())


function reciprocal(value)
    return x =with_restart([
        :return_zero => ()->0,
        :return_value => identity,
        :retry_using => reciprocal]
        ) do
            value == 0 ?
            error(DivisionByZero) :
            1/value
    end
end



handling([DivisionByZero => c -> invoke_restart(:return_zero)]) do
    x = reciprocal(0)
    println("reciprocal(0) = ", x)
end


handling([DivisionByZero => c-> for restart in (:return_one, :return_zero, :die_horribly)
if available_restart(restart)
invoke_restart(restart)
end
end]) do
x = reciprocal(0)
println("reciprocal(0) = ", x)
end 


function infinity() 
    return with_restart([:just_do_it => ()->1/0]) do
        reciprocal(0)
    end
end

handling([DivisionByZero => (c)->invoke_restart(:just_do_it)]) do
    infinity()
end