struct SignalException <: Exception 
    exception::Exception
    must_handle::Bool

end

struct EndOfLine <: Exception end

struct DivisionByZero <: Exception end


const HANDLERS_KEY = :__exceptional_handlers
const RESTARTS_KEY = :__exceptional_restarts



function error(exception)
    #verificar se existem handlers disponiveis
    #se existirem, chamar o handler
    handlers = get(task_local_storage(), HANDLERS_KEY, Pair{Type{<:Exception}, Function}[])
    handled = false
    
    for (name, handler) in reverse(handlers)
        
        if name == exception # encontrou um handler para a excepcao
            handler(exception)
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




function with_restart()
end



function invoke_restart()
end

function with_restart(f , restarts)
   
end







# tests

function reciprocal(x)
    if x == 0
        signal(DivisionByZero)  # Use `throw` instead of `error`
        return 2
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
                error(EndOfLine)
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