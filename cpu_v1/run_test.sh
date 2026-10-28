if [ "$#" -gt 0 ]; then
    # Compiling the src file and generating the bin file

    # Verify if the source file exists
    if [ ! -f "./code/$1.s" ]; then
        echo "Error: Source file './code/$1.s' not found."
        exit 1
    fi

    python ./code/assembler.py "./code/$1.s" "./code/$1.bin"
    
    # Verify if the bin file was created successfully
    if [ ! -f "./code/$1.bin" ]; then
        echo "Error: Failed to create the binary file. Please check the assembler output."
        exit 1
    fi

    ./obj_dir/sim_cpu "+firmware=./code/$1.bin" && surfer dump.vcd
else
    echo "Usage: $0 <firmware_src_file>"
    exit 1
fi 