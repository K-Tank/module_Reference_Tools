"""
Base.@ccallable function custom_CSV_read(file::String)::DataFrame
read CSV and return DataFrame
"""

"""
    Base.@ccallable function write_html(htmltitle::String, htmlbody::String, outputfile::String = "", iopen::Bool = false)::String
        char1 = "<!DOCTYPE html>  <html lang=\"ja\"> \n<head> <meta charset=\"UTF-8\">\n<title> " * htmltitle * " </title>\n<style> </style>\n</head>\n<body>\n" * htmlbody * "\n</body>\n</html>"
write html code to outputfiles
title is htmltitle
main part is htmlbody
"""

 """
 Base.@ccallable function make_html_from_dataframe(pmid_data0::DataFrame, writehtml::Bool = true)::String

 make html file of reference and show it from dataframe
 """


"""
Base.@ccallable function make_html_from_pmid(char1::String, writehtml::Bool = true)::String
Base.@ccallable function make_html_from_pmid(charx::Array{String,1}, writehtml::Bool = true)::Strin
Base.@ccallable function make_html_from_pmid(int::Int64, writehtml::Bool = true)::String
ase.@ccallable Base.@ccallable function make_html_from_pmid(int::Array{Int64,1}, writehtml::Bool = true)::String
    
make html filefrom PMID and show it from dataframe
"""

 """
 Base.@ccallable function make_html_from_csv(csvfile::String, writehtml::Bool = true)::String
 make html file from generated CSV and show it from dataframe
 """


 """
 Base.@ccallable function obtain_medline_from_readcube_bib(bibfile_abs::String, pmid_list_file_abs::String, pubmed_data_processed_file_abs::String)::DataFrame

      obtain and record medline dataframe from internet
      pmid_list_file_abs is list of pmid_data
      pubmed_data_processed_file_abs is csv file
 """
