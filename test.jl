function test()
    println("Hello, World!")
end

function oi()
    test()
end

function lol()
    let 
        function test()
            println("bye, World!")
        end
        return oi()
    end
end


# call lol()

