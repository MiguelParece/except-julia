module ExcepionalExtend     



    
import Base.identity



struct EndOfLine <: Exception end

#exception exclusiva para o to_escape
struct ExitException <: Exception 
    
    token::Any
    value::Any
end

struct DivisionByZero <: Exception end

struct restart_data
    name ::Symbol  # nome do restart
    test :: Function # boolean function
    report :: Function #lista os restarts disponiveis com descricao
    interacive :: Function # apanha inputs do utilizador caso seja necessario
    funct::Function  # funcao a ser executada
end


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


# overwrite da funcao with_restart identity
function with_restart(f, restarts...)
    return to_escape() do exit
        #preparar os restarts 
        current_restarts = get!(task_local_storage(), RESTARTS_KEY, restart_data[])
        orignal_size = length(current_restarts)
        for (name,meta) in restarts
            
            funct = get(meta, :funct, println("No function provided for restart: ", name))
            test = get(meta, :test, true)
            report = get(meta, :report, string(name))
            interactive = get(meta, :interactive, ()->())

            #print the types of the vars : 
            println("Name: ", name, " Test: ", test, " Report: ", report, " Interactive: ", interactive, " Function: ", funct)

            push!(current_restarts, ExcepionalExtend.restart_data(name, test, report, interactive, funct))
        end
        try
            f()
        finally
            task_local_storage()[RESTARTS_KEY] = current_restarts[1:orignal_size] 
        end
    end
end


function available_restart(name)
    restarts = get(task_local_storage(), RESTARTS_KEY, restart_data[])
    for restart in restarts
        if restart == name && restart.test()
            return true
        end
    end
    return false
end


function invoke_restart(name, args...)
    restarts = get(task_local_storage(), RESTARTS_KEY, restart_data[])


    #print ars 
    println("Args: ", args)

    #obter o input caso seja necessario
    for restart in restarts
        if restart.name == name && restart.test()
            if isempty(args)
                args = restart.interacive()
            end
            println("Report for restart: ", restart.report())
            return restart.funct(args...)
        end
    end
    
    println("Restart not found")
    return false #nao encontrou nenhum restart com esse nome
end

function reciprocal(x)
    with_restart(
    :return_value => (;
        funct = (x) -> x,
        test = () -> true,
        report = () -> "Return a custom value",
        interactive = () -> begin
        print("Enter value: ")
        flush(stdout)
        input = readline()
        (parse(Float64, input),)  # Return as a tuple
    end
    )) do 
        x == 0 ? error(DivisionByZero) : 1/x
    end

end


x =handling(DivisionByZero => (c) -> invoke_restart(:return_value)) do
    reciprocal(0)
end
println(x)
end