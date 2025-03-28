module Exceptional


export signal, error, handling, with_restart, available_restart, invoke_restart, to_escape
export DivisionByZero, ExitException, EndOfLine
import Base.identity



struct EndOfLine <: Exception end

#exception exclusiva para o to_escape
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
        println("No Handler found coco")
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


function handling(f, handlers...) # funcao F e pairs de handlers
    #preparar os handlers
    current_handlers = get!(task_local_storage(), HANDLERS_KEY, Pair{Type{<:Exception}, Function}[])
    orignal_size = length(current_handlers)

    for (exception, handler) in handlers
        println("Adding handler for exception: ", exception)
        push!(current_handlers, (exception => handler))
    end
    try
        return f()
    finally
        task_local_storage()[HANDLERS_KEY] = current_handlers[1:orignal_size] 
    end
end


function with_restart(f, restarts...)
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


end # end module

