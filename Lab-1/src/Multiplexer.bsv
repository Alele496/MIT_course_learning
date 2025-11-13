function Bit#(1) and1(Bit#(1) a, Bit#(1) b);
    return a & b;
endfunction

function Bit#(1) or1(Bit#(1) a, Bit#(1) b);
    return a | b;
endfunction

function Bit#(1) xor1( Bit#(1) a, Bit#(1) b );
    return a ^ b;
endfunction

function Bit#(1) not1(Bit#(1) a);
    return ~ a;
endfunction

function Bit#(1) multiplexer1(Bit#(1) sel, Bit#(1) a, Bit#(1) b);
    // return (sel == 0)? a : b;

    /* 
        Exercise 1
     */

    // 1.Reverse sel, a and b merge with not_sel and sel
    /* 
    Bit#(1) not_sel = ~sel;
    Bit#(1) a_path = a & not_sel;
    Bit#(1) b_path = b & sel;
    Bit#(1) out = a_path | b_path;
    return out;
     */
    
    // 2.Expression: out = (a & ~sel) | (b & sel);
    // return out = (a & ~sel) | (b & sel);

    // 3.Use encapsulated and1,or1,not1
    return or1(and1(a, not1(sel)), and1(b, sel));

endfunction

function Bit#(5) multiplexer5(Bit#(1) sel, Bit#(5) a, Bit#(5) b);
    // return (sel == 0)? a : b;

    /* 
        Exercise 2
     */
     
    /*
    Bit#(5) result;
    for (Integer i = 0; i < 5; i = i + 1) begin
        result[i] = multiplexer1(sel, a[i], b[i]);
    end
    return result;
     */
    
    // Exercise 3
    return multiplexer_n(sel, a, b);
endfunction

typedef 5 N;
function Bit#(N) multiplexerN(Bit#(1) sel, Bit#(N) a, Bit#(N) b);
    // return (sel == 0)? a : b;

    /* 
        Exercise 3
     */
    
    Bit#(N) result;
    for (Integer i = 0; i < valueof(N); i = i + 1) begin
        result[i] = multiplexer1(sel, a[i], b[i]);
    end
    return result;
endfunction

//typedef 32 N; // Not needed
function Bit#(n) multiplexer_n(Bit#(1) sel, Bit#(n) a, Bit#(n) b);
    // return (sel == 0)? a : b;

    /* 
        Exercise 3
     */
    // Bit substitution "n"
    Bit#(n) result;
    for (Integer i = 0; i < valueof(n); i = i + 1) begin
        result[i] = multiplexer1(sel, a[i], b[i]);
    end
    return result;
endfunction