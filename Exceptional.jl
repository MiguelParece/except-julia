struct DivisionByZero <: Exception end
struct ExitException <: Exception  
    token::Any
    value::Any
end

function reciprocal(x)
    if x == 0
        signal(DivisionByZero)  # Use `throw` instead of `error`
        return 2
    else
        x = 1 / x
        return x +1
    end
end




function signal(exception)
    return throw(exception())
end


function error(exception)
    return error(exception())
end


function handling(f, handlers)
    try
        f()
    catch e
        for (exception, handler) in handlers
            if e isa exception
                handler(e)
            end
        end
        rethrow(e)
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

reciprocal(0)


handling(() -> reciprocal(0), [(DivisionByZero, c -> println("I saw a division by zero"))])


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
                inner(1)
            elseif n == 1
                outer(1)
            else
                1
            end
        end
    end
end