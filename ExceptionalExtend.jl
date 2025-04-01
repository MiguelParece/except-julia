module ExcepionalExtend     

using Test    
import Base.identity


struct EndOfLine <: Exception end

struct NoSuchFile <: Exception end

#exception exclusiva para o to_escape
struct ExitException <: Exception 
    token::Any
    value::Any
end

struct DivisionByZero <: Exception end


#new     
#estrutura para os restarts
struct restart_data
    name ::Symbol  # nome do restart
    test :: Function # boolean function
    report :: Function #lista os restarts disponiveis com descricao
    interacive :: Function # apanha inputs do utilizador caso seja necessario
    funct::Function  # funcao a ser executada
end


const HANDLERS_KEY = :__exceptional_handlers
const RESTARTS_KEY = :__exceptional_restarts

#new   
#overwrite da funcao error
function error(exception)
    #verificar se existem handlers disponiveis
    #se existirem, chamar o handler

    handlers = get!(task_local_storage(), HANDLERS_KEY, Vector{Vector{Pair{Type{<:Exception}, Function}}}())
    for handler_block in reverse(handlers)
        for (name, handler) in reverse(handler_block)
            if typeof(exception) isa typeof(name) # encontrou um handler para a excepcao
                handler(exception)
                break
            end
        end
    end

    
    #se nao verificar se existem restarts disponiveis e dar prompt ao user

        available_restarts = get_available_restarts()

        if !isempty(available_restarts)
            # listar os restarts disponiveis enumerados
            println("error: ", exception)
            println("Available restarts: ")
            for (i, restart) in enumerate(available_restarts)
                println("$(i): $(restart)")
            end
            #pedir input do numero do restart ao user
            print("Enter the number of the restart you wish to invoke: ")

            flush(stdout)
            input = readline()
            restart_number = parse(Int, input)

            #verificar se o numero e valido
            if restart_number < 1 || restart_number > length(available_restarts)
                println("Invalid restart number")
                return error(exception)
            end

            #invocar o restart

            return invoke_restart(available_restarts[restart_number])


            
        end


    println("No Handler found coco")
    throw(exception)

end


function signal(exception)
    #verificar se existem handlers disponiveis
    #se existirem, chamar o handler
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
        
       # println("oi",exception, handler)
        
        push!(new_handlers_block, (exception => handler))

    end

    #adicionar o bloco de handlers ao array de handlers    
    push!(current_handlers, new_handlers_block)
    
    #println("Entering block :", get!(task_local_storage(), HANDLERS_KEY, Vector{Vector{Pair{Type{<:Exception}, Function}}}()))

    try
         f()
    finally
        #println("Exiting block ")
        task_local_storage()[HANDLERS_KEY] = current_handlers[1:orignal_size] 
    end
end




#new
# overwrite da funcao with_restart identity
function with_restart(f, restarts...)
    return to_escape() do exit
        #preparar os restarts 


        
        
        current_restarts = get!(task_local_storage(), RESTARTS_KEY, restart_data[])
        orignal_size = length(current_restarts)
        #default restart Abort e Retry

        push!(current_restarts, ExcepionalExtend.restart_data(:abort, ()->true, ()->"Abort", ()->(), (args...)->(println("Aborting");Base.exit(1))))
        
        #retry a funcao f()
        push!(current_restarts, ExcepionalExtend.restart_data(:retry, ()->true, ()->"Retry", ()->(), (args...)->f(args...)))

        for (name,meta) in restarts
            
            funct = get(meta, :funct, println("No function provided for restart: ", name))
            test = get(meta, :test, true)
            report = get(meta, :report, string(name))
            interactive = get(meta, :interactive, ()->())

            
            #print the types of the vars : 
            #println("Name: ", name, " Test: ", test, " Report: ", report, " Interactive: ", interactive, " Function: ", funct)

            push!(current_restarts, ExcepionalExtend.restart_data(name, test, report, interactive, (args...)->exit(funct(args...))))
        end
        try

            f()
        finally
            task_local_storage()[RESTARTS_KEY] = current_restarts[1:orignal_size] 
        end
    end
end

#new
function get_available_restarts()
    restarts = get(task_local_storage(), RESTARTS_KEY, restart_data[])
    return [restart.name for restart in restarts if restart.test()]
end

#new
#overwrite da funcao available_restart
function available_restart(name)
    restarts = get(task_local_storage(), RESTARTS_KEY, restart_data[])
    for restart in restarts
        if restart == name && restart.test()
            return true
        end
    end
    return false
end

#new
#overwrite da funcao invoke_restart
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
            (parse(Int, input),) 
        end
    )
    ) do   
        x == 0 ? error(DivisionByZero) : 1/x
    end

end


function write_to_file(filename, data)
    with_restart() do
        #check if the file exists
        if !isfile(filename)
            error(NoSuchFile)
            open(filename, "w") do file
                write(file, data)
            end
        else
            open(filename, "w") do file
                write(file, data)
            end
        end
    end
end





handling(DivisionByZero => (c) -> invoke_restart(:return_value,6)) do
    handling(DivisionByZero => (c) -> invoke_restart(:return_value,2)) do
         y = reciprocal(0)
         @test y == 2
    end
    x= reciprocal(0)
    @test x == 6
end



#write the var x to file
write_to_file("text.txt", string(reciprocal(0)))

#then create the file and choose the retry restart
#@handling DivisionByZero print("Retry") reciprocal(0)


end