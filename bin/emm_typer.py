#!/usr/bin/env python3

import sys
import argparse
import logging

import pandas as pd

logging.basicConfig(level = logging.INFO, format = '%(levelname)s : %(message)s')

def function():
    pass

class GasFeaturesTyper(argparse.ArgumentParser):

    def error(self, message):
        self.print_help()
        sys.stderr.write(f'\nERROR DETECTED: {message}\n')

        sys.exit(1)

if __name__ == "__main__":
    parser = GasFeaturesTyper(prog = 'Compiles all SPNTypeID results',
        description='',
        epilog=''
        )
    parser.add_argument('-f','--reads',
        nargs="+",
        help='Reads in list form.'
        )
    parser.add_argument('-r','--ref-directory',
        type=str,
        help='Directory that contains reference sequences'
        )
    parser.add_argument('-d','--feature-DB',
        type=str,
        help='This is supplied by the nextflow config and can be changed via the usual methods i.e. command line.'
        )

    logging.debug("Run parser to call arguments downstream")
    args = parser.parse_args()
