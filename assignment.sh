#!/bin/bash

install_iqtree2() { # This checks whether IQ-TREE is installed and installs it if not
    if ! command -v iqtree2 &> /dev/null; then
        echo "IQ-TREE2 not found. Installing..."
        wget https://github.com/iqtree/iqtree2/releases/latest/download/iqtree-2.2.2-Linux
        chmod +x iqtree-2.2.2-Linux
        mv iqtree-2.2.2-Linux /usr/local/bin/iqtree2
    else
        echo "IQ-TREE2 is already installed."
    fi
}

parse_yaml() {
    alignment_file=$(yq '.alignment_file' config.yaml)
    alignments=$(yq '.alignments' config.yaml)
    alignment_num=$(yq '.alignment_num' config.yaml)
}

download_alignments_file() { # This downloads the alignment file needed for this analysis if it's not already in the working directory 
    echo "Downloading assignment file ..."
    wget $alignment_file
}    

install_iqtree2
parse_yaml
download_alignments_file

#alignments = ./knownCanonical.exonAA.fa.gz
#alignment_num = 35

echo "File used: $alignments"
echo "Number of exons: $alignment_num"

## PART 1

separate_exons() { # This separates the alignments by exon
    mkdir exons
    count=1
    zless $alignments | while read x;
    do
	if [[ $x  =~ "hg38" ]]; then
	    block=$(echo $x | awk -F '_' '{print ">"$2}')
	elif [[ $x =~ ">" ]]; then
	    block=$block"\n"$(echo $x | awk -F '_' '{print ">"$2}')
	else	    
	    if [[ ! $x =~ ^[[:space:]]*$ ]]; then
		block=$block"\n"$x
	    else
		if [[ $block =~ ">" ]]; then
		    echo -e $block > ./exons/exon$count.fa
		    count=$((count+1))
		    block=""
		fi
		
		if [[ $count -gt $alignment_num ]]; then
		    break
		fi
	    fi
	fi
    done
}

construct_exon_trees() { # This constructs the phylogenetic tree for each exon using iqtree2
    mkdir exon_treefiles
    for i in $(seq 1 $alignment_num);
    do
	iqtree2 -s ./exons/exon$i.fa -redo -pre ./exon_treefiles/exon$i
    done
}

merge_exons() { # This uses the merge_sequences executable to create one long seq from all the exons
    chmod +x merge_sequences
    cd exons
    touch names.txt
    for i in ./*.fa;
    do 
	echo $i >> names.txt
    done
    ../merge_sequences < names.txt > merged_exons.fa
    cd ..
}

construct_all_exons_tree() { # This constructs a tree from all the merged sequence of all the 500 exons
    iqtree2 -s ./exons/merged_exons.fa -redo -pre ./exon_treefiles/merged_exons
}

compare_exon_trees() { # This compares each of the exon trees with the tree of the merged exons
    mkdir comp_reports
    touch comp_reports/exon_comparison_report.txt
    for i in $(seq 1 $alignment_num);
    do
	echo ">merged_exons_total vs exon$i" >> comp_reports/exon_comparison_report.txt
	Rscript compare_trees.R exon_treefiles/merged_exons.treefile exon_treefiles/exon$i.treefile >> comp_reports/exon_comparison_report.txt
	if [ $? -eq 0 ]; then
	    echo "Tree comparison for exon$i successfull"
	else
	    echo "At least one of the alligned sequences of exon$i is full of gaps. IQ-tree2 cannot create a tree successfully for said exon" >> comp_reports/exon_comparison_report.txt
	fi
    done
}


### RUN PART 1

separate_exons
construct_exon_trees
merge_exons
construct_all_exons_tree
compare_exon_trees


## PART 2

separate_genes() { # This separates the different genes into different files
    gene_count=1
    count=1
    mkdir genes
    zless $alignments | while read x;
    do
	if ! [[ -d "genes/gene$gene_count" ]]; then
	    mkdir genes/gene$gene_count
	fi
	
	if [[ $x  =~ "hg38" ]]; then
            block=$(echo $x | awk -F '_' '{print ">"$2}')
	elif [[ $x =~ ">" ]]; then
            block=$block"\n"$(echo $x | awk -F '_' '{print ">"$2}')
        else
            if [[ ! $x =~ ^[[:space:]]*$ ]]; then
                block=$block"\n"$x
            else
                if [[ $block =~ ">" ]]; then
                    echo -e $block > ./genes/gene$gene_count/exon$count.fa
                    count=$((count+1))
                    block=""
		else
		    gene_count=$((gene_count+1))
                    echo $gene_count
                fi
		
                if [[ $count -gt $alignment_num ]]; then
                    break
                fi
            fi
        fi
    done			   
    gene_num=$(find ./genes -mindepth 1 -maxdepth 1 -type d | wc -l)
    echo "The number of genes are $gene_num" 
}

merge_genes() { # This merges exon sequences into genes
    for i in $(seq 1 $gene_num);
    do
	touch genes/gene$i/names$i.txt
	for j in genes/gene$i/*.fa;
	do
	    echo $j >> genes/gene$i/names$i.txt
	done
	./merge_sequences < genes/gene$i/names$i.txt > genes/gene$i/merged_gene$i.fa
    done
}

construct_gene_trees() { # This constructs trees for all genes
    mkdir gene_treefiles
    for i in $(seq 1 $gene_num);
    do
	iqtree2 -s ./genes/gene$i/merged_gene$i.fa -redo -pre ./gene_treefiles/merged_gene$i
    done
}

compare_gene_trees() { # This compares each of the gene trees with the tree of the merged exons                                                                                        
    touch comp_reports/gene_comparison_report.txt
    for i in $(seq 1 $gene_num);
    do
        echo ">merged_exons_total vs gene$i" >> comp_reports/gene_comparison_report.txt
        Rscript compare_trees.R exon_treefiles/merged_exons.treefile gene_treefiles/merged_gene$i.treefile >> comp_reports/gene_comparison_report.txt
        if [ $? -eq 0 ]; then
            echo "Tree comparison for gene$i successfull"
        else
            echo "At least one of the alligned sequences of gene$i is full of gaps. IQ-tree2 cannot create a tree successfully for said gene" >> comp_reports/gene_comparison_report.txt
        fi
    done
}


### RUN PART 2

separate_genes
merge_genes
construct_gene_trees
compare_gene_trees
