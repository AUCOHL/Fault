# parse log files and generate an excel file

import re
import sys, getopt 
import pandas as pd
import xlsxwriter

rx_dict = {
    'File': re.compile(r'File: (?P<file>.*) , Top Module: (?P<top_module>.*)'),
    'Faults': re.compile(r'Found (?P<fault_sites>.*) fault sites in (?P<gates>.*) gates and (?P<ports>.*) ports.'), 
    'Time': re.compile(r'Time elapsed: (?P<time>.*)s.'),
    'Coverage': re.compile(r'Simulations concluded: Coverage (?P<coverage>.*)%'),
    'Iteration': re.compile(r'\((?P<current_coverage>.*)%/(?P<min_coverage>.*)%,\) incrementing to (?P<tv_count>.*).'),
}

def main(argv):

    log_file, output_file = parse_args(argv)

    data = pd.DataFrame(columns=["File", "Top Module", "Fault Sites", "Gate Count", "Ports", "Run Time", "TV Count", "Coverage"])
    benchmark = pd.DataFrame(columns=["Current Coverage", "Minimum Coverage", "TV Count"])
    sheets = {}
    row = {}
    iteration = {}
    
    with open(log_file, 'r') as file_object:
        line = file_object.readline()
        while line:
            # at each line check for a match with a regex
            key, match = _parse_line(line)
            
            if key == "File":
                if row:
                    tv_count = -1 # indicates coverage is met with minimum set tv count; no iterations took place

                    if not benchmark.empty: # if coverage is not met with the minimum tv count
                        sheets[row["File"]] = benchmark
                        tv_count = benchmark.iloc[-1]["TV Count"] 
                        benchmark = pd.DataFrame(columns=["Current Coverage", "Minimum Coverage", "TV Count"])
                    
                    row["TV Count"] = tv_count
                    data = data.append(row, ignore_index=True)
                    
                    row = {}

                row["File"] = match.group(1)
                row["Top Module"] = match.group(2)

            if key == "Faults":
                row["Fault Sites"] = match.group(1)
                row["Gate Count"] = match.group(2)
                row["Ports"] = match.group(3)

            if key == "Time":
                row["Run Time"] = match.group(1)

            if key == "Coverage":
                row["Coverage"] = match.group(1)
            
            if key == "Iteration":
                iteration["Current Coverage"] = match.group(1)
                iteration["Minimum Coverage"] = match.group(2)
                iteration["TV Count"] = match.group(3)

                benchmark = benchmark.append(iteration, ignore_index=True)
            line = file_object.readline()
    
    # write to output excel file
    with pd.ExcelWriter(output_file, engine="openpyxl") as writer:  
        data.to_excel(writer, sheet_name="Benchmarks")
        for file_name, sheet in sheets.items():
            sheet.to_excel(writer, sheet_name=file_name)



def _parse_line(line):

    for key, rx in rx_dict.items():
        match = rx.search(line)
        if match:
            return key, match
    return None, None


def parse_args(argv):

    output_file = "logs.xlsx"
    log_file = ""
    try:
        opts, _ = getopt.getopt(argv, "h:o:f:")
    except getopt.GetoptError:
        print_usage()
        sys.exit(2)
        
    for opt, arg in opts:
        if opt == "-h":
            print_usage()
            sys.exit()
        elif opt == "-o":
            output_file = arg
        elif opt == "-f":
            log_file = arg

    return log_file, output_file

def print_usage():
    print ("parser.py -f <logFile> -o <outputfile>")


if __name__ == "__main__":
   main(sys.argv[1:])