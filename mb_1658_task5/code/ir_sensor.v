module ir_sensor(
	input ir_in,
	output is_object
);
assign is_object = ~ir_in; // IR sensor sends 0 when detects objects in its range.
endmodule