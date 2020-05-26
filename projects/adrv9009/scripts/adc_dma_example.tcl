if { $argc != 1 } {
	puts "This script requires the number of channels to read from memory."
	puts "4 channel (I+Q) example:\n\txsct adc_cma_example.tcl 8"
	puts "2 channel (I+Q) example:\n\txsct adc_cma_example.tcl 4"
	exit 1
}

set start_addr 8388608

set num_samples 16384

set num_bytes_per_sample 2

set num_channels [lindex $argv 0]
if { $num_channels == "" } {
	set num_channels [lindex $argv 1]
}

#Default mrd access size is word
set mrd_size [expr {$num_samples * $num_channels * $num_bytes_per_sample / 4}]

connect
# targets -set -filter {name =~ "*Cortex-A53 #0*"}
targets -set -filter {name =~ "ARM*#0"}

puts "Transferring data from target to adc_dma_example.csv file..."

set read_data [mrd $start_addr $mrd_size]

set fp [open adc_dma_example.csv a]
set index 1
while {$index < [expr {$mrd_size * 2}]} {
	set line ""
	for {set ch 0} {$ch < $num_channels} {incr ch 2} {
		set data [lindex $read_data [expr {$index + $ch}]]
		set data [expr 0x$data]
		set sample_q [expr {$data & 0xFFFF}]
		set sample_i [expr {($data >> 16) & 0xFFFF}]
		append line $sample_i,$sample_q,
	}
	set line [string range $line 0 end-1]
	puts $fp $line
	incr index $num_channels
}
close $fp

puts "Done."

disconnect

exit
