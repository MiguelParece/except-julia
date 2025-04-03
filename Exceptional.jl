module Exceptional


export signal, error, handling, with_restart, available_restart, invoke_restart, to_escape
export DivisionByZero, ExitException, EndOfLine

import Base.identity
using Test


struct EndOfLine <: Exception end

#exception exclusiva para o to_escape
struct ExitException <: Exception 
    
    token::Any
    value::Any
end

abstract type DivisionByZero <: Exception end

struct DivisionByZero_1 <: DivisionByZero end
struct DivisionByZero_2 <: DivisionByZero end

const HANDLERS_KEY = :__exceptional_handlers
const RESTARTS_KEY = :__exceptional_restarts



function error(exception)
    #verificar se existem handlers disponiveis
    #se existirem, chamar o handler
    handlers = get!(task_local_storage(), HANDLERS_KEY, Vector{Vector{Pair{Type{<:Exception}, Function}}}())
    handled = false
    for handler_block in reverse(handlers)
        for (name, handler) in reverse(handler_block)
            if typeof(exception) isa typeof(name) # encontrou um handler para a excepcao
                handler(exception)
                break
            end
        end
    end

    #duvida é suposto dar erro certo ?
    println("No Handler found coco")
    throw(exception)
    
end


function signal(exception)
    #verificar se existem handlers disponiveis
    #se existirem, chamar o handler
    handlers = get!(task_local_storage(), HANDLERS_KEY, Vector{Vector{Pair{Type{<:Exception}, Function}}}())
    handled = false
    for handler_block in reverse(handlers)
        for (name, handler) in reverse(handler_block)
            if typeof(exception) isa typeof(name) # encontrou um handler para a excepcao
                handler(exception)
                break
            end
        end
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
    current_handlers = get!(task_local_storage(), HANDLERS_KEY, Vector{Vector{Pair{Type{<:Exception}, Function}}}())
    orignal_size = length(current_handlers)

   # println("ola", orignal_size)

    new_handlers_block = Pair{Type{<:Exception}, Function}[]

    if(orignal_size > 0)
        #clonar o array de handlers mais recente
      #  println("tentou clonar")
        new_handlers_block = copy(current_handlers[end])
      #  println("clonou")
    end

    for (exception, handler) in handlers
        
        println("oi",exception, handler)
        
        push!(new_handlers_block, (exception => handler))

    end

    #adicionar o bloco de handlers ao array de handlers    
    push!(current_handlers, new_handlers_block)
    
    #println("Entering block :", get!(task_local_storage(), HANDLERS_KEY, Vector{Vector{Pair{Type{<:Exception}, Function}}}()))

    try
        return f()
    finally
        #println("Exiting block ")
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
    for (restart, handler) in Iterators.reverse(restarts)
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

function reciprocal(value)
    with_restart(
        :return_zero => () -> 0,
        :return_value => identity,
        :retry_using => reciprocal
    ) do
        value == 0 ? Exceptional.error(DivisionByZero_2) : 1/value
    end
end


#BUG
handling(DivisionByZero_2 => (c) -> println("ola")) do
    handling(DivisionByZero_2 => (c) -> println("mamas2"),DivisionByZero_2 => (c) -> println("ola")) do
        x = reciprocal(0)
        @test x == 1/2
    end

    reciprocal(0)
end


end # end module

