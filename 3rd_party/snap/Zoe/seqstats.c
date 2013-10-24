/*****************************************************************************\
 seqstats.c

Produces statistics on sequence files

Copyright (C) 2002-2013 Ian Korf

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

\*****************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include "zoe.h"


int ASCII_SET = 256;

int main (int argc, char *argv[]) {
	zoeFile file;
	zoeFastaFile seq = NULL;
	double entropy = 0;
	float f;
	double d;
	int file_count = 0;
	long total_length = 0;
	int this_arg;
	int i;
	long count[256];
	long GC = 0, AT = 0;
	long longest = 0, shortest = INT_MAX;
	
	for(i=0;i<ASCII_SET;i++) count[i] = 0;
	
	/* set the program name */
	zoeSetProgramName(argv[0]);
	
	if (argc == 1) {
		zoeS(stderr, "usage: %s <fasta files>\n", argv[0]);
		exit(1);
	}
	
	for (this_arg = 1; this_arg < argc; this_arg++) {
	
		/* open the file and get the sequences */
		file = zoeOpenFile(argv[this_arg]);
		while ((seq = zoeReadFastaFile(file.stream)) != NULL) {
			file_count++;
			
			/* count the letters */
			for (i = 0; i < seq->length; i++) {
				count[(int) seq->seq[i]]++;
				switch (seq->seq[i]) {
					case 'a': case 'A': case 't': case 'T': AT++; break;
					case 'g': case 'G': case 'c': case 'C': GC++; break;
				}
			}
			total_length += seq->length;
			if (seq->length > longest) longest = seq->length;
			if (seq->length < shortest) shortest = seq->length;
			
			zoeDeleteFastaFile(seq);
		}
		zoeCloseFile(file);
	}
	
	/* output some stats */
	zoeS(stdout, "%d files\n", file_count);
	zoeS(stdout, "%g total letters\n", (float)total_length);
	zoeS(stdout, "range %g to %g\n", (float)shortest, (float)longest);
	f = total_length/file_count;
	zoeS(stdout, "%g average\n", f);
	zoeS(stdout, "%g GC\n", (double)GC / (double)(GC+AT));
	
	for (i=0;i<ASCII_SET;i++) {
		if (count[i] != 0) {
			f = (double)count[i]/total_length;
			d = - ((double)count[i]/total_length)
				* zoeLog2((double)count[i]/total_length);
			zoeS(stdout, "%c\t%g\t%f\n", i, (float)count[i], f);
			entropy += d;
		}
	}
	zoeS(stdout, "entropy = %g bits\n", entropy);
	return 0;
}
