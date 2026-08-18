catch {quit -sim}
onerror {resume}
transcript on

# ModelSim's [info script] does not return the current macro filename. The most
# recent history entry does: "do {<full macro path>}". Derive every other path
# from that location, so the macro works after the complete project is moved.
set macro_command [history event 0]
set macro_path [lindex $macro_command 1]
set script_dir [file dirname $macro_path]

# The macro can live in the project root or in a simulation subfolder. Search
# upward without converting the path to a machine-specific absolute constant.
set project_dir ""
set candidate_dir $script_dir
for {set level 0} {$level < 8} {incr level} {
    if {[file exists [file join $candidate_dir DUT RV32I_CORE.vhd]]} {
        set project_dir $candidate_dir
        break
    }
    set candidate_dir [file join $candidate_dir ".."]
}

if {$project_dir eq ""} {
    error "Could not find the project root above macro: $macro_path"
}

puts "Project directory: $project_dir"

# Keep ModelSim's generated work library outside the project tree.
set temp_root [string map [list "\\" "/"] $env(TEMP)]
set work_dir "$temp_root/project1_test1_modelsim_work"
if {![file exists $work_dir]} {
    vlib $work_dir
}
vmap work $work_dir

# DUT order is explicit because packages must compile before their users.
set dut_sources [list \
    DUT/cond_compilation_package.vhd \
    DUT/const_package.vhd \
    DUT/aux_package.vhd \
    DUT/PLL.vhd \
    DUT/IFETCH.VHD \
    DUT/IDECODE.VHD \
    DUT/CONTROL.VHD \
    DUT/EXECUTE.VHD \
    DUT/DMEMORY.VHD \
    DUT/MUL.vhd \
    DUT/sync.vhd \
    DUT/divider_accelerator.vhd \
    DUT/RV32I_CORE.vhd]

foreach source $dut_sources {
    vcom -2008 [file join $project_dir $source]
}

set tb_source ""
set tb_candidates [list \
    [file join $project_dir tb_test1.vhd] \
    [file join $project_dir TB tb_test1.vhd] \
    [file join $project_dir SIM test1 tb_test1.vhd] \
    [file join $project_dir SIM test1 tb_RV32I_SC.vhd] \
    [file join $script_dir tb_test1.vhd] \
    [file join $script_dir tb_RV32I_SC.vhd]]

foreach candidate $tb_candidates {
    if {[file exists $candidate]} {
        set tb_source $candidate
        break
    }
}

if {$tb_source eq ""} {
    error "Could not locate a test1 VHDL testbench"
}

# Read the selected file and obtain its actual entity name. This supports both
# the original tb_RV32I_SC entity and the newer self-checking tb_test1 entity.
set tb_file [open $tb_source r]
set tb_text [read $tb_file]
close $tb_file
if {![regexp -nocase {entity\s+([A-Za-z0-9_]+)\s+is} $tb_text unused tb_entity]} {
    error "Could not determine the testbench entity in $tb_source"
}

puts "Testbench source: $tb_source"
puts "Testbench entity: $tb_entity"
vcom -2008 $tb_source

vsim -L altera_mf -voptargs=+acc work.$tb_entity

# Self-contained waveform setup; no external waveform macro is required.
view wave
add wave -r sim:/$tb_entity/*

run 25 us
