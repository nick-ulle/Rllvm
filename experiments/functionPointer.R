# The following is a very simple proof of concept that illustrates
# working with function/routine pointers.
# It is a silly example as it is a routine that takes a pointer to a routine
# and then calls it. So we should just call the routine directly, not indirectly.
# But the intent is to illustrate the general idea of pointers to routines
# and how to pass them to another routine and how to invoke them.

# A more interesting example is the canonical sort(x, comparatorFunction)
# or computing pairwise distances between observations with the metric specified
# as a pointer to a routine.

library(Rllvm)

m = Module()

# Create a simple routine that takes a double value and returns that value
# multiplied by 2. This is the routine we will invoke indirectly via a pointer
# to it, i.e.,
#    fun = function(x) x * 2
#
f = Function("fun", DoubleType, list(x = DoubleType), module = m)
b = Block(f)
ir = IRBuilder(b)
x = getParameters(f)$x
two = createConstant(, 2, context = getContext(m))
ir$createReturn(ir$binOp(BinaryOps["FMul"], x, two))


# Next create a proxy routine to which we will pass the pointer to the actual routine
# and a double value. Then we call the routine via its pointer and return the value.
# i.e., 
#   proxy = function(fun, value) fun(value)

funType = functionType(DoubleType, list(DoubleType), FALSE)
funType_p = pointerType(funType)

proxy = Function("proxy", DoubleType, list(fun = funType_p, x = DoubleType), module = m)
b = Block(proxy)
ir = IRBuilder(b)
x = getParameters(proxy)$x   # or short hand proxy$x
fun = getParameters(proxy)$fun
ir$createReturn( ir$createCall( fun, x) )


# Now we invoke this. We need the address of f
ee = ExecutionEngine(m)
fnPtr = getPointerToFunction(f, ee)

# Not using the ee here, but the address fnPtr is still valid
stopifnot(.llvm(proxy, fnPtr, 10.4) == 20.8)

# now using the ee
stopifnot(.llvm(proxy, fnPtr, 10.4, .ee = ee) == 20.8)

##########
# Now test with a routine that we write in C and compile and load via a
# separate DLL.

system("R CMD SHLIB functionPointer_show.c")
dll = dyn.load("functionPointer_show.so")
sym = getNativeSymbolInfo("test", dll)$address
all.equal(.llvm(proxy, sym, 10.4), 31.2)
