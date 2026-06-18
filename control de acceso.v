module Ponchador (
    input clk, input reset,
    input btn_next, input btn_bit, input btn_shift, input btn_enter,
    output [7:0] leds_proto,
    output [6:0] seg1, output [6:0] seg2, output [6:0] seg3,
    output reg led_v, output reg led_r,
    output buzzer
);

    
    reg [29:0] cont_global = 0; 
    reg [25:0] t_verde = 0;     
    reg [2:0] estado_actual = 0; 
    reg [1:0] posicion_user = 0; // 0:Jose, 1:Juan, 2:Mali, 3:Lia
    reg [7:0] registro_clave = 0; 
    reg [3:0] cuenta_bits = 0; 
    reg [2:0] errores = 0; 
    reg [3:0] completados = 0; 

    // Registro para capturar los botones sin rebote
    reg ant_ent, ant_shift, ant_bit;
    reg [19:0] delay_debounce = 0;
    reg bloqueo_shift = 0;

    always @(posedge clk) begin
        cont_global <= cont_global + 1;
        
        // Guardando el estado anterior para el flanco de subida
        ant_ent <= btn_enter; 
        ant_bit <= btn_bit; 
        ant_shift <= btn_shift;

        if (reset) begin
            estado_actual <= 0; posicion_user <= 0; errores <= 0; completados <= 0;
            led_v <= 0; led_r <= 0; bloqueo_shift <= 0;
            registro_clave <= 0; cuenta_bits <= 0; t_verde <= 0;
        end else begin
            
            // Navegar entre los nombres (solo funciona si estamos en la pantalla de nombres)
            if (estado_actual == 1 && btn_bit && !ant_bit) begin
                posicion_user <= posicion_user + 1;
                led_v <= 0; 
                led_r <= 0;
            end

            // Meter los bits uno a uno usando el Shift
            if (btn_shift && !ant_shift && !bloqueo_shift) begin
                bloqueo_shift <= 1; 
                delay_debounce <= 0;
                
                if (estado_actual == 1 || estado_actual == 6) begin 
                    estado_actual <= 2; 
                    registro_clave <= 0; 
                    cuenta_bits <= 0; 
                end else if (estado_actual == 2 && cuenta_bits < 8) begin
                    registro_clave <= {registro_clave[6:0], btn_bit}; 
                    cuenta_bits <= cuenta_bits + 1;
                end
            end

       
            if (bloqueo_shift) begin
                delay_debounce <= delay_debounce + 1;
                if (delay_debounce == 20'hFFFFF) bloqueo_shift <= 0;
            end

            // Control del flujo 
            case (estado_actual)
                0: if (btn_enter && !ant_ent) estado_actual <= 1; // Presiona Enter para empezar
                
                2: begin // Validar cuando se metan los 8 bits
                    if (cuenta_bits == 8 && btn_enter && !ant_ent) begin
                        if (errores >= 3) begin // Alarma activa -> Modo Administrador
                            if (registro_clave == 8'hFF) begin 
                                led_v <= 1; led_r <= 0; errores <= 0; estado_actual <= 7; 
                            end else begin
                                led_r <= 1; estado_actual <= 6; // Se queda bloqueado
                            end
                        end else begin // Modo Normal de usuarios
                            if ((posicion_user==0 && registro_clave==8'hA1) || (posicion_user==1 && registro_clave==8'hB2) ||
                                (posicion_user==2 && registro_clave==8'hC3) || (posicion_user==3 && registro_clave==8'hD4)) begin
                                led_v <= 1; led_r <= 0;
                                completados[posicion_user] <= 1;
                                errores <= 0;
                                estado_actual <= 7;
                            end else begin
                                led_r <= 1; 
                                errores <= errores + 1;
                                if (errores >= 2) begin estado_actual <= 6; errores <= 3; end 
                                else estado_actual <= 1; // Te devuelve a la lista
                            end
                        end
                    end
                end

                7: begin // Mantiene el led verde encendido un segundo
                    t_verde <= t_verde + 1;
                    if (t_verde >= 26'd24_000_000) begin 
                        t_verde <= 0; led_v <= 0;
                        if (errores == 0 && completados == 0) estado_actual <= 0; 
                        else estado_actual <= 1; 
                    end
                end
                
                6: ; // Sistema bloqueado. Poner clave maestra FF para salir.
            endcase
        end
    end

    
    localparam _A=7'b1110111, _E=7'b1111001, _I=7'b0000110, _J=7'b0011110, 
               _L=7'b0111000, _M=7'b0110111, _N=7'b0110111, _O=7'b0111111, 
               _S=7'b1101101, _U=7'b0111110, __=7'b0000000, _DASH=7'b1000000,
               _C=7'b0111001, _K=7'b1110110, _D=7'b1011110;

    reg [6:0] buffer_letras[0:7];
    
    always @(*) begin
        case (estado_actual)
            0: begin buffer_letras[0]=__; buffer_letras[1]=__; buffer_letras[2]=_DASH; buffer_letras[3]=_DASH; buffer_letras[4]=_DASH; buffer_letras[5]=__; buffer_letras[6]=__; buffer_letras[7]=__; end
            6: begin buffer_letras[0]=__; buffer_letras[1]=__; buffer_letras[2]=_A; buffer_letras[3]=_D; buffer_letras[4]=_M; buffer_letras[5]=__; buffer_letras[6]=__; buffer_letras[7]=__; end
            2: begin 
                if (errores >= 3) begin buffer_letras[0]=__; buffer_letras[1]=__; buffer_letras[2]=_A; buffer_letras[3]=_D; buffer_letras[4]=_M; buffer_letras[5]=__; buffer_letras[6]=__; buffer_letras[7]=__; end
                else begin 
                    case(posicion_user)
                        2'd0: begin buffer_letras[0]=__; buffer_letras[1]=__; buffer_letras[2]=_J; buffer_letras[3]=_O; buffer_letras[4]=_S; buffer_letras[5]=_E; buffer_letras[6]=__; buffer_letras[7]=__; end
                        2'd1: begin buffer_letras[0]=__; buffer_letras[1]=__; buffer_letras[2]=_J; buffer_letras[3]=_U; buffer_letras[4]=_A; buffer_letras[5]=_N; buffer_letras[6]=__; buffer_letras[7]=__; end
                        2'd2: begin buffer_letras[0]=__; buffer_letras[1]=__; buffer_letras[2]=_M; buffer_letras[3]=_A; buffer_letras[4]=_L; buffer_letras[5]=_I; buffer_letras[6]=__; buffer_letras[7]=__; end
                        2'd3: begin buffer_letras[0]=__; buffer_letras[1]=__; buffer_letras[2]=_L; buffer_letras[3]=_I; buffer_letras[4]=_A; buffer_letras[5]=__; buffer_letras[6]=__; buffer_letras[7]=__; end
                    endcase
                end
            end
            default: begin
                case(posicion_user)
                    2'd0: begin buffer_letras[0]=__; buffer_letras[1]=__; buffer_letras[2]=_J; buffer_letras[3]=_O; buffer_letras[4]=_S; buffer_letras[5]=_E; buffer_letras[6]=__; buffer_letras[7]=__; end
                    2'd1: begin buffer_letras[0]=__; buffer_letras[1]=__; buffer_letras[2]=_J; buffer_letras[3]=_U; buffer_letras[4]=_A; buffer_letras[5]=_N; buffer_letras[6]=__; buffer_letras[7]=__; end
                    2'd2: begin buffer_letras[0]=__; buffer_letras[1]=__; buffer_letras[2]=_M; buffer_letras[3]=_A; buffer_letras[4]=_L; buffer_letras[5]=_I; buffer_letras[6]=__; buffer_letras[7]=__; end
                    2'd3: begin buffer_letras[0]=__; buffer_letras[1]=__; buffer_letras[2]=_L; buffer_letras[3]=_I; buffer_letras[4]=_A; buffer_letras[5]=__; buffer_letras[6]=__; buffer_letras[7]=__; end
                endcase
            end
        endcase
    end

    wire [2:0] indice_scroll = cont_global[27:25]; 
    assign seg1 = buffer_letras[(indice_scroll + 0) % 8]; 
    assign seg2 = buffer_letras[(indice_scroll + 1) % 8]; 
    assign seg3 = buffer_letras[(indice_scroll + 2) % 8];
    
   
    assign leds_proto = registro_clave;

    // Salida de audio del Buzzer
    assign buzzer = (estado_actual == 6 || (estado_actual == 2 && errores >= 3)) ? cont_global[14] : 
                    (led_v) ? (cont_global[13] & led_v) : 1'b0;

endmodule