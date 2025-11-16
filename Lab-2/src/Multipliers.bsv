// Reference functions that use Bluespec's '*' operator
function Bit#(TAdd#(n,n)) multiply_unsigned( Bit#(n) a, Bit#(n) b );
    UInt#(n) a_uint = unpack(a);
    UInt#(n) b_uint = unpack(b);
    UInt#(TAdd#(n,n)) product_uint = zeroExtend(a_uint) * zeroExtend(b_uint);
    return pack( product_uint );
endfunction

function Bit#(TAdd#(n,n)) multiply_signed( Bit#(n) a, Bit#(n) b );
    Int#(n) a_int = unpack(a);
    Int#(n) b_int = unpack(b);
    Int#(TAdd#(n,n)) product_int = signExtend(a_int) * signExtend(b_int);
    return pack( product_int );
endfunction



// Multiplication by repeated addition
function Bit#(TAdd#(n,n)) multiply_by_adding( Bit#(n) a, Bit#(n) b );
    // TODO: Implement this function in Exercise 2

    // Shift accumulation calculation
    // a x b = The sum of (a Shift b left to the number of bits correponding to 1)
    Bit#(TAdd#(n,n)) result_uint = 0;
    
    for (Integer i = 0; i < valueOf(n); i = i + 1) begin
        if (b[i] == 1'b1) begin
            // Strong type conversion to corresponding result type(2n).
            Bit#(TAdd#(n,n)) temp = zeroExtend(a) << i;
            result_uint = result_uint + temp;
        end
    end

    /* 
    // Serial Shift Accumulation Calculation on Reference Network
    Bit#(n) tp = 0;
    Bit#(n) low_uint = 0;

    for (Integer i = 0; i < valueOf(n); i = i + 1) begin
        Bit#(TAdd#(n,1)) sum = zeroExtend(tp) + zeroExtend(b);

        // Bit by bit add
        low_uint[i] = sum[0];
        tp = sum[valueOf(n):1];

    end
    return {tp, low_uint};
    */

    return result_uint;
endfunction



// Multiplier Interface
interface Multiplier#( numeric type n );
    method Bool start_ready();
    method Action start( Bit#(n) a, Bit#(n) b );
    method Bool result_ready();
    method ActionValue#(Bit#(TAdd#(n,n))) result();
endinterface



// Folded multiplier by repeated addition
module mkFoldedMultiplier( Multiplier#(n) ) provisos(Add#(1, a__, n));
    // You can use these registers or create your own if you want
    Reg#(Bit#(n)) a <- mkRegU();
    Reg#(Bit#(n)) b <- mkRegU();
    Reg#(Bit#(n)) prod <- mkRegU();
    Reg#(Bit#(n)) tp <- mkRegU();
    Reg#(Bit#(TAdd#(TLog#(n),1))) i <- mkReg( fromInteger(valueOf(n)+1) );

    // rule mulStep( /* guard goes here */ );
    rule mulStep( i < fromInteger(valueOf(n)) );
        // TODO: Implement this in Exercise 4

        // Fix bit check
        Bit#(n) opt = (a[0] == 0 ) ? 0 : b;

        a <= a >> 1;
        Bit#(TAdd#(n,1)) sum = zeroExtend(tp) + zeroExtend(opt);
        prod <= {sum[0], prod[valueOf(n)-1:1]};
        tp <= sum[valueOf(n):1];
        i <= i + 1;

        /* 
        // Note: Reg#(Bit#(TAdd#(n,n))) prod <- mkRegU();
        // Directly extended to 2n, no need to build through high and low positions.

        // Cycle detection b is 1, then a move left i bits.
        if (b[0] == 1'b1) begin
            prod <= prod + zeroExtend(a);
        end

        a <= a << 1;
        b <= b >> 1;
        i <= i + 1;
         */
        

    endrule

    method Bool start_ready();
        // TODO: Implement this in Exercise 4
        // return False;

        return (i == fromInteger(valueOf(n) + 1));

    endmethod

    method Action start( Bit#(n) aIn, Bit#(n) bIn );
        // TODO: Implement this in Exercise 4
        // Initialize Reg
        a <= aIn;
        b <= bIn;
        prod <= 0;
        // tp <= 0;
        i <= 0;

    endmethod

    method Bool result_ready();
        // TODO: Implement this in Exercise 4
        // return False;

        return (i == fromInteger(valueOf(n)));

    endmethod

    method ActionValue#(Bit#(TAdd#(n,n))) result();
        // TODO: Implement this in Exercise 4
        // return 0;

        i <= i + 1;
        return {tp, prod};

    endmethod
endmodule



// Booth Multiplier
module mkBoothMultiplier( Multiplier#(n) );
    Reg#(Bit#(TAdd#(TAdd#(n,n),1))) m_neg <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),1))) m_pos <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),1))) p <- mkRegU;
    Reg#(Bit#(TAdd#(TLog#(n),1))) i <- mkReg( fromInteger(valueOf(n)+1) );

    // rule mul_step( /* guard goes here */ );
    rule mulStep( i < fromInteger(valueOf(n)) );
        // TODO: Implement this in Exercise 6

        let pr = p[1:0];
        Bit#(TAdd#(TAdd#(n,n),1)) p_bit = 0;
        
        p_bit = case(pr)
            2'b01: return p + m_pos;
            2'b10: return p + m_neg;
            default: return p;
        endcase;
        
        /* 
        if ( pr == 2'b01 ) begin 
            p_bit = p_bit + m_pos;
        end else if (pr == 2'b10) begin 
            p_bit = p_bit + m_neg;
        end else begin 

        end
        */

        Int#(TAdd#(TAdd#(n,n),1)) p_int = unpack(p_bit);
        p <= pack(p_int >> 1);
        i <= i + 1;

    endrule

    method Bool start_ready();
        // TODO: Implement this in Exercise 6
        // return False;
        return (i == fromInteger(valueOf(n) + 1));
    endmethod

    method Action start( Bit#(n) m, Bit#(n) r );
        // TODO: Implement this in Exercise 6
        m_pos <= {m, 0};
        m_neg <= {(-m), 0};
        p <= {0, r, 1'b0};
        i <= 0;

    endmethod

    method Bool result_ready();
        // TODO: Implement this in Exercise 6
        // return False;
        return (i == fromInteger(valueOf(n)));
    endmethod

    method ActionValue#(Bit#(TAdd#(n,n))) result();
        // TODO: Implement this in Exercise 6
        // return 0;
        i <= i + 1;
        // res = 2n most significant bits of p;
        return p[2 * valueOf(n):1];
    endmethod
endmodule



// Radix-4 Booth Multiplier
module mkBoothMultiplierRadix4( Multiplier#(n) );
    Reg#(Bit#(TAdd#(TAdd#(n,n),2))) m_neg <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),2))) m_pos <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),2))) p <- mkRegU;
    Reg#(Bit#(TAdd#(TLog#(n),1))) i <- mkReg( fromInteger(valueOf(n)/2+1) );

    // rule mul_step( /* guard goes here */ );
    rule mulStep( i < fromInteger(valueOf(n)/2) );
        // TODO: Implement this in Exercise 8

        let pr = p[2:0];
        Bit#(TAdd#(TAdd#(n,n),2)) p_bit = unpack(p);

        p_bit = case(pr)
            3'b000: return p;
            3'b001: return p + m_pos;
            3'b010: return p + m_pos;
            3'b011: return p + (m_pos << 1);
            3'b100: return p + (m_neg << 1);
            3'b101: return p + m_neg;
            3'b110: return p + m_neg;
            3'b111: return p;
        endcase;

        Int#(TAdd#(TAdd#(n,n),2)) p_int = unpack(p_bit);
        p <= pack(p_int >> 2);
        i <= i + 1;


    endrule

    method Bool start_ready();
        // TODO: Implement this in Exercise 8
        // return False;
        return i == fromInteger(valueOf(n)/2 + 1);
    endmethod

    method Action start( Bit#(n) m, Bit#(n) r );
        // TODO: Implement this in Exercise 8
        m_pos <= {m[valueOf(n)-1], m, 0};
        m_neg <= {(-m)[valueOf(n)-1], -m, 0};
        p <= {0, r, 1'b0};
        i <= 0;
    endmethod

    method Bool result_ready();
        // TODO: Implement this in Exercise 8
        // return False;
        return i == fromInteger(valueOf(n)/2);
    endmethod

    method ActionValue#(Bit#(TAdd#(n,n))) result();
        // TODO: Implement this in Exercise 8
        // return 0;
        // res = p with MSB and LSB chopped off;
        i <= i + 1;
        return p[2 * valueOf(n):1];
    endmethod
endmodule
