# obtain and record medline dataframe from internet based on Readcube-generated bib file
#
# HGow to use
# First, Generate ris file from Readcube, selecting ALL references
#
# You can obtain reference data from DataFrame by
# make_html_from_dataframe
#
# You can obtain reference data from (Array of) String or Int64 of pmid (String may be separated by comma) by
# make_html_from_pmid
#
# You can obtain reference data from gcsv file by
# make_html_from_csv
#
# bibfile_abs is path of Readcube-generated ris file
# pmid_list_file_abs is path of list of pmid_data
# pubmed_data_processed_file_abs is path of csv file

#if new Reference style is needed, edit add_name_list_and_data_to_pmid_data or add_several_reference_string(pmid_data)
# in the module_Refrence_Tools
module module_Reference_Tools
    export obtain_medline_from_readcube_bib
    export make_html_from_pmid
    export make_html_from_csv
    export make_html_from_dataframe
    export custom_CSV_read
    export write_html

    using DataFrames
    using HTTP
    using CSV
    using Dates

# """
# sub funcyion of StringToIntpart
# """
    Base.@ccallable function LetterToInt(char::Char)::Int64
        x = Int(char)
        if ((x>=48) && (x<=57))
            return(x-48)
        else
            throw("invalid input; not number")
        end
        #vecx =  ['0'; '1'; '2'; '3'; '4'; '5'; '6'; '7'; '8'; '9']
        #return(findfirst((vecx .== char))-1)
    end

# """
# convert String to Integer; if cannot, throw error
# """
    Base.@ccallable function StringToIntpart(char::String)::Int64
        if (occursin(r"^-",char))
            signx = -1
            charx = replace(char, r"^-"=>"")
        else
            signx = 1
            charx = replace(char, r"^\+"=>"")
        end

        x1 = reverse(LetterToInt.(collect(charx)))

        fact = 1
        summed1 = 0
        for ix in 1:length(x1)
            summed1 = summed1 + fact * x1[ix]
            fact = fact*10
        end
        return(summed1*signx)
    end



    # """
    # #select item not included in old, from new
    # """
    Base.@ccallable function select_new(new::Array{String,1}, old::Array{String,1})::Array{String,1}
        boo = fill(false, length(new));
        for ix in 1:length(new)
            boo[ix] = !any(new[ix] .== old)
        end
        return(new[boo])
    end

# """
# #select item not included in old, from new (sumbol version)
# """
    Base.@ccallable function select_new(new::Array{Symbol,1}, old::Array{Symbol,1})::Array{Symbol,1}
        boo = fill(false, length(new));
        for ix in 1:length(new)
            boo[ix] = !any(new[ix] .== old)
        end
        return(new[boo])
    end

# """
# returns Array{String,1}
# each element is PMID concatenated with comma ("11253645,14522846,...""), with maximum unitnum
# """
    Base.@ccallable function join_by_unit(vec::Array{String,1}, unitnum::Int64, collapse::String=",")::Array{String,1}
        if (length(vec) == 0)
            return(fill("",1))
        end
        if (unitnum <= 0)
            return(fill("",1))
        end

        num = div(length(vec),unitnum)+1
        ret = fill("", num)
        for jx in 1:num
            rang = (unitnum*(jx-1)+1):min(unitnum*jx, length(vec))
            ret[jx] = join(vec[rang], collapse)
        end
        return(ret)
    end

# """
#  read CSV as all String
#  """
    Base.@ccallable function custom_CSV_read(file::String)::DataFrame
        temp = CSV.read(file;  missingstring = "this_is_missing_hahaha", limit = 2)
        types = fill(String, size(temp,2))
        return(CSV.read(file; missingstring = "this_is_missing_hahaha", types = types))
    end

# """
# delete first and last space and kaigyo   #
# """
    Base.@ccallable function delete_gomi_from_text(char::String)::String
        char = replace(char, r"^[ \n]*"=>"")
        char = replace(char, r"[ \n]*$"=>"")
        return(char)
    end

# """
# Base.@ccallable function keep_first(vec::Array{String,1})::Array{Bool, 1}
#     return is Array{Bool, 1}
# if a nth element is not equal to any of 1st to n-1th, return[n] is true
# """
    Base.@ccallable function keep_first(vec::Array{String,1})::Array{Bool, 1}
        if length(vec)<=1
            return(fill(true,size(vec)))
        end

        boo = fill(true, size(vec))
        for ix in 2:(length(vec))
            boo[ix] = all(vec[1:(ix-1)] .!= vec[ix])
        end
        return(boo)
    end


# """    Base.@ccallable function convert_readcube_bib(bibfile_abs::String, pmid_list_file_abs::String, unitnum::Int64=150, all_refresh::Bool=false)::Array{String,1}
# convert "readcube-exported bib file" to PMID Array, and write it  to "PMID_list_from_Julia.txt"
# returned value is new PMID list, concatenated with comma
# #
# bibfile_absis abs. path of bib file
# pmid_list_file_abs is abs. path of generated PMID Array file
# """
    Base.@ccallable function convert_readcube_bib(bibfile_abs::String, pmid_list_file_abs::String, unitnum::Int64=150, all_refresh::Bool=false)::Array{String,1}
        text = try
                    String.(split(read(bibfile_abs, String), "\n"));
                catch
                    fill("",0)
        end

        if (length(text)==0)
            return(fill("", 1))
        end

        text_old = try
                    String.(split(read(pmid_list_file_abs, String), ","));
                catch
                    fill("",0)
        end

        text_old_0 = copy(text_old)

        if (all_refresh)
            text_old = fill("",0)
        end

        #text = String.(split(read(bibfile_abs, String), "\n"));

        boo = fill(false, length(text));
        reg = r"pmid *= *\{.[^\{\}]*\}"

        # char = "pmid={28716377},"
        # occursin(reg,char)

        for ix in 1:length(text)
            boo[ix] = occursin(reg, text[ix]);
        end
        #length(boo[boo])
        text = text[boo]
        for ix in 1:length(text)
            text[ix] = replace(text[ix], r"pmid *= *\{"=>"")
            text[ix] = replace(text[ix], "},"=>"")
            text[ix] = replace(text[ix], " "=>"")
        end

        text = select_new(text, text_old) #only new PMID list are picked up

        if (all_refresh)
            text_old = select_new(text_old_0, text)
        end

        text_all = unique( [text_old; text] )

        if (length(text)==0)
            return(fill("", 1))
        end

        char1 =  join_by_unit(text, unitnum, ",")
        char2 = join(text_all, ",")

        try
            write(pmid_list_file_abs, char2);
        catch
            ;
        end
        return( char1 )
    end




    # """
    # Base.@ccallable function merge_dataframe(dfa::DataFrame, dfb::DataFrame)::DataFrame
    #
    #     merge two DataFrames
    #     both dfa and dfb column are left (if duplicated dfa column is left)
    #     """
    Base.@ccallable function merge_dataframe(dfa::DataFrame, dfb::DataFrame)::DataFrame
        df1 = copy(dfa)
        df2 = copy(dfb)
        boo = fill(true, size(df2, 1))

        for ix in 1:size(df2, 1)
            try
                boo[ix] = all(df2.PMID[ix] .!= df1.PMID)
            catch
                ;
            end
        end
        df2 = df2[boo, :]


        both = unique([names(df1); names(df2)])
        boo_n1 = fill(false, length(both))
        boo_n2 = fill(false, length(both))

        for ix in 1:length(both)
            boo_n1[ix] = all(both[ix] .!= names(df1))
            boo_n2[ix] = all(both[ix] .!= names(df2))
        end

        c_df1 = both[boo_n1]
        c_df2 = both[boo_n2]

        for ix in 1:length(c_df1)
            df1[c_df1[ix]] = fill("", size(df1,1))
        end
        for ix in 1:length(c_df2)
            df2[c_df2[ix]] = fill("", size(df2,1))
        end

        names(df1) == names(df2)

        return( copy(vcat(df1, df2)) )
     #only unincluded in df1

        # #return( join(df1, df2, on = :PMID, kind = :outer, makeuniwue) )
        #
        # data_vacant = DataFrame(fill(fill("", (size(df1,1) + size(df2,1))), length(both)), Symbol.(both))
        #
        # data_vacant
        #
        # if ((size(df1,1) != 0))
        #     for kx in names(df1)
        #         for jx in 1:size(df1,1)
        #             data_vacant[jx, kx] = df1[jx, kx] * ""
        #         end
        #     end
        # end
        #
        # if ((size(df2,1) != 0))
        #     for kx in names(df2)
        #         for ix in 1:size(df2,1)
        #             data_vacant[(size(df1,1) + jx), kx] = df2[jx, kx]
        #         end
        #     end
        # end
        #
        # #both are size 0
        # return(data_vacant)
    end

# """
# Base.@ccallable function get_pubmed_dataframe_from_pmid_list(char0::String)::DataFrame
#     obtain DataFrame from char0
#     char0 is String of single PMID or several PMID concatenated with comma
#
# Base.@ccallable function get_pubmed_dataframe_from_pmid_list(char::Array{String,1})::DataFrame
#     Array{String, 1} VERSION
#
#
# """
    Base.@ccallable function get_pubmed_dataframe_from_pmid_list(char0::String)::DataFrame
        if (char0 == r" *")
            #return DataFrame()
            return(data_vacant)
        end

        address = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=" * char0 * "&rettype=medline&retmode=text"
        http_message = replace(String(HTTP.request("GET", address; verbose=0)), "\r"=> "")
        http_message = replace(http_message, "\n      "=>" ")
        http_message = replace(http_message, "\""=>"")
        #http_message = replace(http_message, ","=>"\\,")

        vecx = String.(split(http_message, "\n\n"));
        vecx = vecx[occursin.("PMID- ", vecx)]
        vecx = delete_gomi_from_text.(vecx)

        dataframe_pmid = DataFrame()
        for ix in vecx
            vec2 = String.(split(ix, "\n"));
            vec2 = vec2[occursin.("-", SubString.(vec2,1,5))]

            df = DataFrame( Symbol("PMID") => fill("", 1), Symbol("OWN") => fill("", 1), Symbol("STAT") => fill("", 1), Symbol("DCOM") => fill("", 1), Symbol("LR") => fill("", 1), Symbol("IS") => fill("", 1), Symbol("VI") => fill("", 1), Symbol("IP") => fill("", 1), Symbol("DP") => fill("", 1), Symbol("TI") => fill("", 1), Symbol("PG") => fill("", 1), Symbol("LID") => fill("", 1), Symbol("AB") => fill("", 1), Symbol("CI") => fill("", 1), Symbol("FAU") => fill("", 1),Symbol("AU") => fill("", 1), Symbol("AD") => fill("", 1), Symbol("LA") => fill("", 1), Symbol("PT") => fill("", 1), Symbol("DEP") => fill("", 1), Symbol("PL") => fill("", 1), Symbol("TA") => fill("", 1), Symbol("JT") => fill("", 1), Symbol("JID") => fill("", 1), Symbol("RN") => fill("", 1), Symbol("SB") => fill("", 1), Symbol("MH") => fill("", 1), Symbol("OTO") => fill("", 1), Symbol("OT") => fill("", 1), Symbol("EDAT") => fill("", 1), Symbol("MHDA") => fill("", 1), Symbol("CRDT") => fill("", 1), Symbol("PHST") => fill("", 1), Symbol("AID") => fill("", 1), Symbol("PST") => fill("", 1), Symbol("SO")=> fill("", 1), Symbol("GR") => fill("", 1), Symbol("CIN") => fill("", 1), Symbol("PMC") => fill("", 1), Symbol("MID") => fill("", 1), Symbol("RF") => fill("", 1), Symbol("COIS") => fill("", 1), Symbol("SI") => fill("", 1), Symbol("AUID") => fill("", 1), Symbol("CN") => fill("", 1), Symbol("IR") => fill("", 1), Symbol("FIR") => fill("", 1), Symbol("EIN") => fill("", 1), Symbol("UOF") => fill("", 1), Symbol("EFR") => fill("", 1) )
            #if (length(vec2) != 0)
            if (length(vec2) != 0)
                vec0 = fill("", length(vec2))
                mat = [vec0 vec0]


                for jx in 1:length(vec2)
                    mat[jx,:] = ( String.(split(vec2[jx], "-",limit=2)) )
                end
                mat = delete_gomi_from_text.(mat)

                item = unique(mat[:,1])
                mat2 = [item fill("", length(item))]

                for kx in 1:length(item)
                    symb = Symbol(item[kx])
                    vecitem = (mat[:,2])[(mat[:,1]) .== item[kx]]
                    df[symb] = fill(join(vecitem, "\n"),1) #single row dataframe for ix
                end
            end
            dataframe_pmid = merge_dataframe(dataframe_pmid, df)
        end
        return(dataframe_pmid)
    end

    Base.@ccallable function get_pubmed_dataframe_from_pmid_list(char::Array{String,1})::DataFrame
        data_vacant = DataFrame( Symbol("PMID") => fill("", 0), Symbol("OWN") => fill("", 0), Symbol("STAT") => fill("", 0), Symbol("DCOM") => fill("", 0), Symbol("LR") => fill("", 0), Symbol("IS") => fill("", 0), Symbol("VI") => fill("", 0), Symbol("IP") => fill("", 0), Symbol("DP") => fill("", 0), Symbol("TI") => fill("", 0), Symbol("PG") => fill("", 0), Symbol("LID") => fill("", 0), Symbol("AB") => fill("", 0), Symbol("CI") => fill("", 0), Symbol("FAU") => fill("", 0),Symbol("AU") => fill("", 0), Symbol("AD") => fill("", 0), Symbol("LA") => fill("", 0), Symbol("PT") => fill("", 0), Symbol("DEP") => fill("", 0), Symbol("PL") => fill("", 0), Symbol("TA") => fill("", 0), Symbol("JT") => fill("", 0), Symbol("JID") => fill("", 0), Symbol("RN") => fill("", 0), Symbol("SB") => fill("", 0), Symbol("MH") => fill("", 0), Symbol("OTO") => fill("", 0), Symbol("OT") => fill("", 0), Symbol("EDAT") => fill("", 0), Symbol("MHDA") => fill("", 0), Symbol("CRDT") => fill("", 0), Symbol("PHST") => fill("", 0), Symbol("AID") => fill("", 0), Symbol("PST") => fill("", 0), Symbol("SO")=> fill("", 0), Symbol("GR") => fill("", 0), Symbol("CIN") => fill("", 0), Symbol("PMC") => fill("", 0), Symbol("MID") => fill("", 0), Symbol("RF") => fill("", 0), Symbol("COIS") => fill("", 0), Symbol("SI") => fill("", 0), Symbol("AUID") => fill("", 0), Symbol("CN") => fill("", 0), Symbol("IR") => fill("", 0), Symbol("FIR") => fill("", 0), Symbol("EIN") => fill("", 0), Symbol("UOF") => fill("", 0), Symbol("EFR") => fill("", 0) )

        dfret = data_vacant # DataFrame()
        for char0 in char
            dfret =  merge_dataframe(dfret, get_pubmed_dataframe_from_pmid_list(char0))
        end
        return(dfret)
    end

# """
# Base.@ccallable function add_char_to_pubmed_csv(char::String, csvfile::String = "", returnonlynew::Bool = false)::DataFrame
#     #char is PMID1,PMID2,PMID3....,PMIDn
#     ## get PMIDx reference information and add to CSV file
#     #if returnonlynew is true, returns added database, else, return merged one
#
# Base.@ccallable function add_char_to_pubmed_csv(char::Array{String,1}, csvfile::String, returnonlynew::Bool = false)::DataFrame
#     Array version
# """
    Base.@ccallable function add_char_to_pubmed_csv(char::String, csvfile::String = "", returnonlynew::Bool = false)::DataFrame
        data_vacant = DataFrame( Symbol("PMID") => fill("", 0), Symbol("OWN") => fill("", 0), Symbol("STAT") => fill("", 0), Symbol("DCOM") => fill("", 0), Symbol("LR") => fill("", 0), Symbol("IS") => fill("", 0), Symbol("VI") => fill("", 0), Symbol("IP") => fill("", 0), Symbol("DP") => fill("", 0), Symbol("TI") => fill("", 0), Symbol("PG") => fill("", 0), Symbol("LID") => fill("", 0), Symbol("AB") => fill("", 0), Symbol("CI") => fill("", 0), Symbol("FAU") => fill("", 0),Symbol("AU") => fill("", 0), Symbol("AD") => fill("", 0), Symbol("LA") => fill("", 0), Symbol("PT") => fill("", 0), Symbol("DEP") => fill("", 0), Symbol("PL") => fill("", 0), Symbol("TA") => fill("", 0), Symbol("JT") => fill("", 0), Symbol("JID") => fill("", 0), Symbol("RN") => fill("", 0), Symbol("SB") => fill("", 0), Symbol("MH") => fill("", 0), Symbol("OTO") => fill("", 0), Symbol("OT") => fill("", 0), Symbol("EDAT") => fill("", 0), Symbol("MHDA") => fill("", 0), Symbol("CRDT") => fill("", 0), Symbol("PHST") => fill("", 0), Symbol("AID") => fill("", 0), Symbol("PST") => fill("", 0), Symbol("SO")=> fill("", 0), Symbol("GR") => fill("", 0), Symbol("CIN") => fill("", 0), Symbol("PMC") => fill("", 0), Symbol("MID") => fill("", 0), Symbol("RF") => fill("", 0), Symbol("COIS") => fill("", 0), Symbol("SI") => fill("", 0), Symbol("AUID") => fill("", 0), Symbol("CN") => fill("", 0), Symbol("IR") => fill("", 0), Symbol("FIR") => fill("", 0), Symbol("EIN") => fill("", 0), Symbol("UOF") => fill("", 0), Symbol("EFR") => fill("", 0) )

        pmid_data_old = try
            custom_CSV_read(csvfile);
            pmid_data_old = pmid_data_old[(pmid_data_old.PMID .!= ""), :]
        catch
            data_vacant #DataFrame()
        end

        pmid_data_new = try
            get_pubmed_dataframe_from_pmid_list(char)
        catch
            data_vacant #DataFrame()
        end

        pmid_data = merge_dataframe(pmid_data_old, pmid_data_new)

        try
            CSV.write(csvfile, pmid_data)
        catch
            ;
        end

        if (returnonlynew)
            return(pmid_data_new)
        end
        return(pmid_data)
    end

    #char is PMID1,PMID2,PMID3....,PMIDn
    ## get PMIDx reference information and add to CSV file
    #if returnonlynew is true, returns added database, else, return merged one
    Base.@ccallable function add_char_to_pubmed_csv(char::Array{String,1}, csvfile::String, returnonlynew::Bool = false)::DataFrame
        data_vacant = DataFrame( Symbol("PMID") => fill("", 0), Symbol("OWN") => fill("", 0), Symbol("STAT") => fill("", 0), Symbol("DCOM") => fill("", 0), Symbol("LR") => fill("", 0), Symbol("IS") => fill("", 0), Symbol("VI") => fill("", 0), Symbol("IP") => fill("", 0), Symbol("DP") => fill("", 0), Symbol("TI") => fill("", 0), Symbol("PG") => fill("", 0), Symbol("LID") => fill("", 0), Symbol("AB") => fill("", 0), Symbol("CI") => fill("", 0), Symbol("FAU") => fill("", 0),Symbol("AU") => fill("", 0), Symbol("AD") => fill("", 0), Symbol("LA") => fill("", 0), Symbol("PT") => fill("", 0), Symbol("DEP") => fill("", 0), Symbol("PL") => fill("", 0), Symbol("TA") => fill("", 0), Symbol("JT") => fill("", 0), Symbol("JID") => fill("", 0), Symbol("RN") => fill("", 0), Symbol("SB") => fill("", 0), Symbol("MH") => fill("", 0), Symbol("OTO") => fill("", 0), Symbol("OT") => fill("", 0), Symbol("EDAT") => fill("", 0), Symbol("MHDA") => fill("", 0), Symbol("CRDT") => fill("", 0), Symbol("PHST") => fill("", 0), Symbol("AID") => fill("", 0), Symbol("PST") => fill("", 0), Symbol("SO")=> fill("", 0), Symbol("GR") => fill("", 0), Symbol("CIN") => fill("", 0), Symbol("PMC") => fill("", 0), Symbol("MID") => fill("", 0), Symbol("RF") => fill("", 0), Symbol("COIS") => fill("", 0), Symbol("SI") => fill("", 0), Symbol("AUID") => fill("", 0), Symbol("CN") => fill("", 0), Symbol("IR") => fill("", 0), Symbol("FIR") => fill("", 0), Symbol("EIN") => fill("", 0), Symbol("UOF") => fill("", 0), Symbol("EFR") => fill("", 0) )

        pmid_data_old = try
            custom_CSV_read(csvfile)
        catch
            data_vacant #DataFrame()
        end

        pmid_data_new = try
            get_pubmed_dataframe_from_pmid_list(char)
        catch
            data_vacant
        end

        pmid_data = merge_dataframe(pmid_data_old, pmid_data_new)

        try
            CSV.write(csvfile, pmid_data)
        catch
            ;
        end

        if (returnonlynew)
            return(pmid_data_new)
        end
        return(pmid_data)
    end

    Base.@ccallable function two_string_vector_combination(veca::Array{String, 1}, vecb::Array{String, 1})::Array{String, 1}
        # veca = ["DEP_"; "DP_"; ""]
        # vecb = ["Year"; "Month"; "Monthname"; "Monthabbr"; "Day"]
        vecx = fill("", 0)
        for jx in 1:length(veca)
            vecx = [vecx; (veca[jx] .* vecb)]
        end
        return(vecx)
    end

    Base.@ccallable function return_year_monthx3_day_sub_sub(charx0::String)::Array{String, 1}
        charx = replace(charx0, "\n"=>" ");
        charx = replace(charx, r" +"=>" ");
        charx = replace(charx, ", "=>" ");
        charx = replace(charx, r"^ "=>"");
        charx = replace(charx, r" $"=>"");

        char2 = String.(split(charx, " "));
        if (length(char2) < 3)
            return(fill("", 5))
        end

        date_in = try
            Dates.Date(charx, "yyyy u dd");
        catch
            try
                Dates.Date(charx, "yyyy U dd");
            catch
                return(fill("", 5))
            end
        end

        if (typeof(date_in) == Nothing)
            return(fill("", 5))
        end
        return(
        [string(year(date_in)); string(month(date_in)); monthname(date_in); monthabbr(date_in); string(day(date_in)); ]
        )
    end

    Base.@ccallable function return_year_monthx3_day_sub(charx::String)::Array{String, 1}
        charx = replace(charx, "\n"=>" ");
        charx = replace(charx, r" +"=>" ");
        charx = replace(charx, ", "=>" ");
        charx = replace(charx, r"^ "=>"");
        charx = replace(charx, r" $"=>"");

        retval = return_year_monthx3_day_sub_sub(charx)

        if (fill("", 5) != retval)
            return(retval)
        end

        char2 = String.(split(charx, " "));
        retval = fill("", 5)

        if (length(char2) < 3)
            char2 = [char2; fill("", (3 - length(char2)))]
        end

        x = try
            StringToIntpart(char2[1]); #parse(Int64, char2[1])
        catch
            0
        end

        if (typeof(x) != Int64)
            x = 0
        end

        if ((year(today()) < x) || (x < 1900))
            return(fill("", 5))
        end
        retval[1] = string(x)

        allmonth = [monthname.(1:12); monthabbr.(1:12)]

        y = findfirst(allmonth .== char2[2])
        if (typeof(y) == Nothing)
            return(retval)
        end

        y = mod(y-1, 12) + 1
        retval[2] = string(y)
        retval[3] = monthname(y)
        retval[4] = monthabbr(y)

        return(retval)
    end

    # charx = "2015 Janz"
    # return_year_monthx3_day_sub(charx)

    #return [year; month; monthname; monthabbr; day; ]
    Base.@ccallable function return_year_monthx3_day(charx::String)::Array{String, 1}
        if (charx == "")
            return(fill("", 5))
        end

        try
            (date_in = Dates.Date(charx, "yyyymmdd"));
            return(
            [string(year(date_in)); string(month(date_in)); monthname(date_in); monthabbr(date_in); string(day(date_in)); ]
            )
        catch
            return(return_year_monthx3_day_sub(charx))
        end
    end

    Base.@ccallable function vector_of_vector_to_array(vec::Array{Array{String,1},1})::Array{Union{String,Missing},2}
        nrow = length(vec)
        leng = fill(0, nrow)
        for ix in 1:nrow
            leng[ix] = length(vec[ix])
        end
        ncol = maximum(leng)

        myarray = Array{Union{String,Missing},2}(missing, nrow, ncol)
        for ix in 1:nrow
            myarray[ix, 1:length(vec[ix])] = vec[ix]
        end
        return(myarray)
    end

    # Base.@ccallable function vector_of_vector_to_array(vec)
    #     mytype = typeof(vec[1][1])
    #     nrow = length(vec)
    #     leng = fill(0, nrow)
    #     for ix in 1:nrow
    #         leng[ix] = length(vec[ix])
    #     end
    #     ncol = maximum(leng)
    #
    #     myarray = Array{Union{mytype,Missing},2}(missing, nrow, ncol)
    #     for ix in 1:nrow
    #         myarray[ix, 1:length(vec[ix])] = vec[ix]
    #     end
    #     return(myarray)
    # end

    # """
    # return splitted String (String Format) of String
    # return( String.(split(char, sep)) )
    # """
    Base.@ccallable function mysplit(char::String, sep::String)::Array{String, 1}
        return( String.(split(char, sep)) )
    end

    #return splitted Vector{String} (String Format) by char
    Base.@ccallable function mysplit(char::Array{String, 1}, sep::String)::Array{Array{String,1},1}
        vecx = split.(char, sep)
        ret = fill(fill("",2), length(vecx))

        for ix in 1:length(char)
            ret[ix] = String.(vecx[ix])
        end
        return( ret )
    end

    #First split Strng by sep1 then split substring by sep2...
    Base.@ccallable function doublesplit(char::String, sep1::String, sep2::String)::Array{Array{String,1},1}
        vecx = mysplit(char, sep1)
        # return(typeof(vecx))
        ret = fill(fill("",2), length(vecx))

        for ix in 1:length(vecx)
            ret[ix] = mysplit(vecx[ix], sep2)
        end
        return( ret )
    end

    #First split Array{String, 1} by sep1 then split substring by sep2...
    Base.@ccallable function doublesplit(char::Array{String, 1}, sep1::String, sep2::String)::Array{Array{Array{String,1},1},1}
        # sep2num = maximum(length.(mysplit.(char, sep2)))
        # sep1num = maximum(length.(mysplit.(char, sep1)))
        ret = fill(fill(fill("",2),2), length(char))
        for jx in 1:length(char)
            ret[jx] = doublesplit(char[jx], sep1, sep2)
        end
        return( ret )
    end
    # mysplit("a b n", " ")
    # mysplit(["a b n"; "e r t t"; "gfgf hg"], " ")
    #length( fill(fill("",1000), 12) )
    # charx="19781203"
    # #charx="1978 Dec"
    # return_year_monthx3_day(charx)
    # charx = "2015 Jan 4"
    # return_year_monthx3_day(charx)

# """
# Base.@ccallable function add_name_list_and_data_to_pmid_data(pmid_data0::DataFrame)::DataFrame
#     add author name list and DEP&DP year, month, day
# """
    Base.@ccallable function add_name_list_and_data_to_pmid_data(pmid_data0::DataFrame)::DataFrame
        pmid_data = copy(pmid_data0)
        ##subroutine
        reg=r"[#\\$%&_{}<>^|~\\\\]<>"
        for jx in (names(pmid_data))
            vecx = (pmid_data[jx])
            for ix in 1:length(vecx)
                (pmid_data[jx])[ix] = replace((pmid_data[jx])[ix], reg=>"")
            end
        end

        rownum = size(pmid_data,1)

        veca = ["DEP_"; "DP_"; ""]
        vecb = ["Year"; "Month"; "Monthname"; "Monthabbr"; "Day"]
        vecx = two_string_vector_combination(veca, vecb)

        symb = Symbol.(vecx)

        arr1 = vector_of_vector_to_array(return_year_monthx3_day.(pmid_data.DEP))
        arr2 = vector_of_vector_to_array(return_year_monthx3_day.(pmid_data.DP))

        arr3 = vector_of_vector_to_array(return_year_monthx3_day.(pmid_data.DEP))
        arr4 = vector_of_vector_to_array(return_year_monthx3_day.(pmid_data.DP))

        arr = [arr1 arr2 arr4]
        #arr[12,:]

        for ix in 1:size(arr3, 1)
            if (arr3[ix, 1] == "")
                arr3[ix, 1:5] = arr2[ix, 1:5]
            end
            if (arr4[ix, 1] == "")
                arr4[ix, 1:5] = arr1[ix, 1:5]
            end
        end
        # arr3: DEP優先
        # arr4: DP優先  Use this

        for ix in 1:15
            pmid_data[symb[ix]] = arr[:,ix]
        end

        allfau = doublesplit(pmid_data.FAU, "\n", ",")

        # allfau[67]
        # pmid_data[67:67,:]
        # size(pmid_data,1)

        pmid_data.Firstname_Full = fill("",rownum)
        pmid_data.Firstname_0 = fill("",rownum)
        pmid_data.Firstname_1 = fill("",rownum)
        pmid_data.Firstname_2 = fill("",rownum)
        pmid_data.Firstname_3 = fill("",rownum)
        pmid_data.Firstname_4 = fill("",rownum)
        pmid_data.Firstname_5 = fill("",rownum)
        pmid_data.Lastname = fill("",rownum)

        for kx in 1:rownum
            firstname = fill("", length(allfau[kx]))
            fs0 = fill("", length(allfau[kx]))
            fs1 = fill("", length(allfau[kx]))
            fs2 = fill("", length(allfau[kx]))
            fs3 = fill("", length(allfau[kx]))
            fs4 = fill("", length(allfau[kx]))
            fs5 = fill("", length(allfau[kx]))
            lastname = fill("", length(allfau[kx]))

            for jx in 1:length(allfau[kx])
                firstname[jx] = try
                    allfau[kx][jx][2]
                catch
                    ""
                end
                firstname[jx] = replace(firstname[jx], r" +"=>" ")
                firstname[jx] = replace(firstname[jx], r"^ "=>"")
                firstname[jx] = replace(firstname[jx], r" $"=>"")

                fs0[jx] = replace(firstname[jx], r"[^A-Z-]"=>"") #A-B
                fs1[jx] = replace(fs0[jx], "-"=>"") #AB

                fs2[jx] = replace(fs0[jx], r"[A-Z]"=>function(char) return(char * " "); end)
                fs2[jx] = replace(fs2[jx], " -"=>"-")
                fs2[jx] = replace(fs2[jx], r" +$"=>"") #A Z-H

                fs3[jx] = replace(fs1[jx], r"[A-Z]"=>function(char) return(char * " "); end)
                fs3[jx] = replace(fs3[jx], r" +$"=>"") #A Z H

                fs4[jx] = replace(fs0[jx], r"[A-Z]"=>function(char) return(char * ". "); end)
                fs4[jx] = replace(fs4[jx], r" +$"=>"") #A. Z. -H.

                fs5[jx] = replace(fs1[jx], r"[A-Z]"=>function(char) return(char * ". "); end)
                fs5[jx] = replace(fs5[jx], r" +$"=>"") #A. Z. H.

                lastname[jx] = replace(allfau[kx][jx][1], r" +"=>" ")
                lastname[jx] = replace(lastname[jx], r"^ "=>"")
                lastname[jx] = replace(lastname[jx], r" $"=>"")
            end

            pmid_data.Firstname_Full[kx] = join(firstname , "\n")
            pmid_data.Firstname_0[kx] = join(fs0 , "\n")
            pmid_data.Firstname_1[kx] = join(fs1 , "\n")
            pmid_data.Firstname_2[kx] = join(fs2 , "\n")
            pmid_data.Firstname_3[kx] = join(fs3 , "\n")
            pmid_data.Firstname_4[kx] = join(fs4 , "\n")
            pmid_data.Firstname_5[kx] = join(fs5 , "\n")
            pmid_data.Lastname[kx] = join(lastname , "\n")
        end

        return(pmid_data)
    end

# """
#     #authorstyle = ["#Lastname"; " "; "#Firstname_1"]
#     #Lastname and #Firstname_XXX are replaced with variables
#     Firstname_Full is full version
#     Firstname_0 is A-B style
#     Firstname_1 is AB
#     Firstname_2 is A Z-H
#     Firstname_3 is A Z H
#     Firstname_4 is A. Z. -H.
#     Firstname_5 is A. Z. H
#
#     #get author list for eachrow
# """
    Base.@ccallable function get_each_author(pmid_data0::DataFrame, authorstyle::Array{String, 1} = ["#Lastname"; " "; "#Firstname_1"])::Array{String, 1}
        pmid_data = copy(pmid_data0)
        rownum = size(pmid_data, 1)
        ret = fill("", rownum)

        for kx in 1:rownum
            vecvec = fill(fill("",1), length(authorstyle))
            boox = fill(true, length(authorstyle))

            for jx in 1:length(authorstyle)
                if (occursin(r"^ *#", authorstyle[jx]))
                    vecvec[jx] = String.(split( (pmid_data[kx:kx, :])[Symbol(replace(authorstyle[jx], r"^ *#"=>""))][1], "\n") )
                    boox[jx] = false
                end
            end

            num = length.(vecvec)
            maxnum = maximum(num)
            for jx in 1:length(authorstyle)
                if (boox[jx])
                    vecvec[jx] = fill(authorstyle[jx], maxnum)
                end
            end

            char = fill("", maxnum)
            for jx in 1:length(authorstyle)
                char = char .* vecvec[jx]
            end

            ret[kx]= join(char, "\n")
        end
        return(ret)
    end

# """
#     ##get author List
#     #max_all #max author number expressed without et al
#     #etal_num #author number written when et al is used
#     #authorstyle: authorstyle
#     #sep_vec
#     #[1] #sep between authors
#     #[2] #sep between last two authors
#     #[3] #sep between only TWO auhtors
#     #[4] #sep between author and other part
#     #[5] #et. al
# """
    Base.@ccallable function get_author_list(pmid_data0::DataFrame, max_all::Int64 = 1, etal_num::Int64 = 1,
        authorstyle::Array{String, 1} = ["#Lastname"; " "; "#Firstname_1"],
        sep_vec::Array{String, 1} = [", "; ", and"; " and "; ". "; ", et. al. "])::Array{String, 1}

        pmid_data = copy(pmid_data0)
        sepauthor = sep_vec[1]
        seplast2 = sep_vec[2]
        sep2 = sep_vec[3]
        sepafter = sep_vec[4]
        etal = sep_vec[5]

        #########Base.@ccallable function(pmid_data)
        author_list = get_each_author(pmid_data, authorstyle)

        max_all2 = max_all
        etal_num2 = min(etal_num, max_all2)

        if (max_all2 <= 1)
            for ix in 1:length(author_list)
                vec2 = String.(split(author_list[ix], "\n"))

                if (length(vec2) == 1)
                    author_list[ix] = author_list[ix] * sepafter
                else
                    author_list[ix] = vec2[1] * etal
                end
            end
            return(author_list);
        end

        if (max_all2 == 2)
            for ix in 1:length(author_list)
                vec2 = String.(split(author_list[ix], "\n"))

                if (length(vec2) == 1)
                    author_list[ix] = author_list[ix] * sepafter
                elseif (length(vec2) == 2)
                    author_list[ix] = join(vec2, sep2) * sepafter
                else
                    author_list[ix] = join(vec2[1:2], sepauthor) * etal
                end
            end
            return(author_list);
        end

        for ix in 1:length(author_list)
            vec2 = String.(split(author_list[ix], "\n"))

            if (length(vec2) == 1)
                author_list[ix] = author_list[ix] * sepafter
            elseif (length(vec2) == 2)
                author_list[ix] = join(vec2, sep2) * sepafter
            elseif (length(vec2) <= max_all2)
                author_list[ix] = join(vec2[1:(length(vec2)-1)], sepauthor) * seplast2 * vec2[length(vec2)] * sepafter
            else
                author_list[ix] = join(vec2[1:etal_num2], sepauthor) * etal
            end

            # char = author_list[ix]
            # loc = findlast("\n", char)
            # char = SubString( char, 1:( minimum(loc)-1 ) ) * seplast2 * SubString( char, ( maximum(loc)+1 ):lastindex(char) )
            # author_list[ix] = replace(char, "\n"=>sepauthor)
        end
        return(author_list);
        ######end of Base.@ccallable function
    end

    # """
    #     ##make a reference style
    #     #max_all #max author number expressed without et al
    #     #etal_num #author number written when et al is used
    #     #authorstyle: authorstyle
    #
    #     #sep_vec
    #     #[1] #sep between authors
    #     #[2] #sep between last two authors
    #     #[3] #sep between only TWO auhtors
    #     #[4] #sep between author and other part
    #     #[5] #et. al
    #
    #     #refstyle
    #     "%author_list" is replaced with author list Array{String}
    #     #TI etc is MEDLINE item
    # """
    Base.@ccallable function add_single_reference_string(pmid_data0::DataFrame, refname::String, max_all::Int64 = 1, etal_num::Int64 = 1,
        authorstyle::Array{String, 1} = ["#Lastname"; " "; "#Firstname_1"],
        sep_vec::Array{String, 1} = [", "; ", and"; " and "; ". "; ", et. al. "],
        refstyle = ["%author_list"; "#TI"; " "; "#TA"; " "; "#Year"; " <b>"; "#VI"; "</b>: "; "#PG"; ". "]
        )::DataFrame
        pmid_data = copy(pmid_data0)
        author_list = get_author_list(pmid_data, max_all, etal_num, authorstyle, sep_vec)

        rownum = size(pmid_data, 1)
        ret = fill("", rownum)

        vecvec = fill(fill("", rownum), length(refstyle))

        for jx in 1:length(refstyle)
            if (refstyle[jx] == "%author_list")
                vecvec[jx] = author_list
            elseif (occursin(r"^ *#", refstyle[jx]))
                vecvec[jx] = pmid_data[Symbol(replace(refstyle[jx], r"^ *#"=>""))]
            else
                reg=r"[#\\$%&_{}<>^|~\\\\]<>"
                charx = replace(refstyle[jx], reg=>"")
                vecvec[jx] = fill(charx, rownum)
            end
            ret = ret .* vecvec[jx]
        end

        ret2 = copy(ret)

        for ix in 1:length(ret2)
            ret2[ix] = replace(ret2[ix], "<b>"=>"\\textbf{")
            ret2[ix] = replace(ret2[ix], "<i>"=>"\\textit{")
            ret2[ix] = replace(ret2[ix], "</b>"=>"}")
            ret2[ix] = replace(ret2[ix], "</i>"=>"}")
        end

        if (refname != "")
            refname3 = Symbol("Ref_" * refname * "_html")
            refname4 = Symbol("Ref_" * refname * "_tex")

            if (all(refname3 .!= names(pmid_data)))
                pmid_data[refname3] = ret
            end
            if (all(refname4 .!= names(pmid_data)))
                pmid_data[refname4] = ret2
            end
        end
        # val = fill(fill("",1),2)
        # val[1] = ret
        # val[2] = ret2
        return(pmid_data)
    end
# """
# Base.@ccallable function add_several_reference_string(pmid_data0::DataFrame)::DataFrame
# add several reference stylesheet to  pmid_data0
# """
    Base.@ccallable function add_several_reference_string(pmid_data0::DataFrame)::DataFrame
        pmid_data = copy(pmid_data0)
        max_all = 1 #max author number expressed without et al
        etal_num = 1 #author number written when et al is used

        authorstyle = ["#Lastname"; " "; "#Firstname_1"] #style of author
        sep_vec = [", "; ", and "; " and "; ". "; ", et. al. "]

        refstyle = ["%author_list"; "#TA"; " "; "#Year"; " <b>"; "#VI"; "</b>: "; "#PG"; ". "]

        #get reference string
        pmid_data = add_single_reference_string(pmid_data, "0", max_all, etal_num, authorstyle, sep_vec, refstyle)



        max_all = 6
        etal_num = 3

        authorstyle = ["#Lastname"; " "; "#Firstname_1"] #style of author
        sep_vec = [", "; ", and "; " and "; ". "; ", et. al. "]

        refstyle = ["%author_list"; "#TI"; " "; "#TA"; " "; "#Year"; " <b>"; "#VI"; "</b>: "; "#PG"; ". "]

        pmid_data = add_single_reference_string(pmid_data, "Lancet", max_all, etal_num, authorstyle, sep_vec, refstyle)

        return(pmid_data)
    end

# """
# Base.@ccallable function add_PMID_to_list_and_write_to_csv(char0::String, pmid_list_file_abs::String, pubmed_data_generated_file_abs::String)::DataFrame
# """
    Base.@ccallable function add_PMID_to_list_and_write_to_csv(char0::String, pmid_list_file_abs::String, pubmed_data_generated_file_abs::String)::DataFrame
        char = replace(char0, " "=>"")
        char = replace(char, "\t"=>"")
        char = replace(char, "\n"=>",")
        char = replace(char, r",+"=>",")

        char = replace(char, "?term="=>"")
        char = replace(char, r"https://www-ncbi-nlm-nih-gov.*/pubmed/"=>"")
        char = replace(char, "https://www.ncbi.nlm.nih.gov/pubmed/"=>"")

        if (occursin(r"[^0-9,]", char))
            return(DataFrame( Symbol("PMID") => fill("", 0), Symbol("OWN") => fill("", 0), Symbol("STAT") => fill("", 0), Symbol("DCOM") => fill("", 0), Symbol("LR") => fill("", 0), Symbol("IS") => fill("", 0), Symbol("VI") => fill("", 0), Symbol("IP") => fill("", 0), Symbol("DP") => fill("", 0), Symbol("TI") => fill("", 0), Symbol("PG") => fill("", 0), Symbol("LID") => fill("", 0), Symbol("AB") => fill("", 0), Symbol("CI") => fill("", 0), Symbol("FAU") => fill("", 0),Symbol("AU") => fill("", 0), Symbol("AD") => fill("", 0), Symbol("LA") => fill("", 0), Symbol("PT") => fill("", 0), Symbol("DEP") => fill("", 0), Symbol("PL") => fill("", 0), Symbol("TA") => fill("", 0), Symbol("JT") => fill("", 0), Symbol("JID") => fill("", 0), Symbol("RN") => fill("", 0), Symbol("SB") => fill("", 0), Symbol("MH") => fill("", 0), Symbol("OTO") => fill("", 0), Symbol("OT") => fill("", 0), Symbol("EDAT") => fill("", 0), Symbol("MHDA") => fill("", 0), Symbol("CRDT") => fill("", 0), Symbol("PHST") => fill("", 0), Symbol("AID") => fill("", 0), Symbol("PST") => fill("", 0), Symbol("SO")=> fill("", 0), Symbol("GR") => fill("", 0), Symbol("CIN") => fill("", 0), Symbol("PMC") => fill("", 0), Symbol("MID") => fill("", 0), Symbol("RF") => fill("", 0), Symbol("COIS") => fill("", 0), Symbol("SI") => fill("", 0), Symbol("AUID") => fill("", 0), Symbol("CN") => fill("", 0), Symbol("IR") => fill("", 0), Symbol("FIR") => fill("", 0), Symbol("EIN") => fill("", 0), Symbol("UOF") => fill("", 0), Symbol("EFR") => fill("", 0) ))
        end

        text = String.(split(char, ","));

        text_old = try
                    String.(split(read(pmid_list_file_abs, String), ","));
                catch
                    fill("",0)
        end

        text_all = unique([text_old; select_new(text, text_old)])
        #text = String.(split(read(bibfile_abs, String), "\n"));

        char2 = join(text_all, ",")

        try
            write(pmid_list_file_abs, char2);
        catch
            ;
        end

        pmid_data = add_char_to_pubmed_csv(char, pubmed_data_generated_file_abs, true)
        pmid_data = add_name_list_and_data_to_pmid_data(pmid_data)
        pmid_data = add_several_reference_string(pmid_data)
        return(copy(pmid_data))
    end

    Base.@ccallable function add_PMID_to_list_and_write_to_csv(char0::Array{String, 1}, pmid_list_file_abs::String, pubmed_data_generated_file_abs::String)::DataFrame
        subdata = DataFrame( Symbol("PMID") => fill("", 0), Symbol("OWN") => fill("", 0), Symbol("STAT") => fill("", 0), Symbol("DCOM") => fill("", 0), Symbol("LR") => fill("", 0), Symbol("IS") => fill("", 0), Symbol("VI") => fill("", 0), Symbol("IP") => fill("", 0), Symbol("DP") => fill("", 0), Symbol("TI") => fill("", 0), Symbol("PG") => fill("", 0), Symbol("LID") => fill("", 0), Symbol("AB") => fill("", 0), Symbol("CI") => fill("", 0), Symbol("FAU") => fill("", 0),Symbol("AU") => fill("", 0), Symbol("AD") => fill("", 0), Symbol("LA") => fill("", 0), Symbol("PT") => fill("", 0), Symbol("DEP") => fill("", 0), Symbol("PL") => fill("", 0), Symbol("TA") => fill("", 0), Symbol("JT") => fill("", 0), Symbol("JID") => fill("", 0), Symbol("RN") => fill("", 0), Symbol("SB") => fill("", 0), Symbol("MH") => fill("", 0), Symbol("OTO") => fill("", 0), Symbol("OT") => fill("", 0), Symbol("EDAT") => fill("", 0), Symbol("MHDA") => fill("", 0), Symbol("CRDT") => fill("", 0), Symbol("PHST") => fill("", 0), Symbol("AID") => fill("", 0), Symbol("PST") => fill("", 0), Symbol("SO")=> fill("", 0), Symbol("GR") => fill("", 0), Symbol("CIN") => fill("", 0), Symbol("PMC") => fill("", 0), Symbol("MID") => fill("", 0), Symbol("RF") => fill("", 0), Symbol("COIS") => fill("", 0), Symbol("SI") => fill("", 0), Symbol("AUID") => fill("", 0), Symbol("CN") => fill("", 0), Symbol("IR") => fill("", 0), Symbol("FIR") => fill("", 0), Symbol("EIN") => fill("", 0), Symbol("UOF") => fill("", 0), Symbol("EFR") => fill("", 0) )

        for ix in char0
            subdata = merge_dataframe(subdata, add_PMID_to_list_and_write_to_csv(ix, pmid_list_file_abs, pubmed_data_generated_file_abs))
        end
        return(copy(subdata))
    end

    Base.@ccallable function get_pmid_from_URL(char::String)::String
        char = replace(char, "?term="=>"")
        char = replace(char, r"https://www-ncbi-nlm-nih-gov.*/pubmed/"=>"")
        char = replace(char, "https://www.ncbi.nlm.nih.gov/pubmed/"=>"")
        return(char)
    end #of Base.@ccallable function

    #write html file and return String
    Base.@ccallable function write_html(htmltitle::String, htmlbody::String, outputfile::String = "", iopen::Bool = false)::String
        char1 = "<!DOCTYPE html>  <html lang=\"ja\"> \n<head> <meta charset=\"UTF-8\">\n<title> " * htmltitle * " </title>\n<style> </style>\n</head>\n<body>\n" * htmlbody * "\n</body>\n</html>"

        try
            write(outputfile, char1)
        catch
            ;
        end
        if (iopen)
            try
                run(`explorer $outputfile`)
            catch
                ;
            end
        end
        return(char1)
    end

    Base.@ccallable function char_from_0_to_9XX(x::Int64)::Char
        return(Char(0x30+x))
    end

    Base.@ccallable function Int64ToString(x::Int64)::String
        if (x < 0)
            char0 = "-"
            x2 = -x
        else
            char0 = ""
            x2 = x
        end
        return( char0 * join( char_from_0_to_9XX.(reverse(digits(x2))) ) )
    end

# """
# Base.@ccallable function make_html_from_dataframe(pmid_data0::DataFrame, writehtml::Bool = true)::String
#
# make html file of reference and show it from dataframe
# """
    Base.@ccallable function make_html_from_dataframe(pmid_data0::DataFrame, writehtml::Bool = true)::String
        pmid_data= copy(pmid_data0)
        # pmid_data.FAU

        boo1 = fill(false, length(names(pmid_data)))
        boo2 = fill(false, length(names(pmid_data)))
        for ix in 1:length(names(pmid_data))
            boo1[ix] = occursin(r"Ref_.*_html", String.(names(pmid_data))[ix])
            boo2[ix] = occursin("PMID", String.(names(pmid_data))[ix])
        end

        boo = boo1.|boo2
        boo1x = boo1[boo]
        boo2x = boo2[boo]

        #sum(Int64.(boo))
        pmid_data = pmid_data[boo]
        newname = String.(names(pmid_data))
        newname2 = fill("", length(newname))

        for ix in 1:length(newname)
            newname[ix] = replace(newname[ix], "_html" => ")")
            newname[ix] = replace(newname[ix], "Ref_" => "Ref (type ")
        end

        newname[boo1x] = "\n<h2>" .* newname[boo1x] .* "</h2>\n"
        newname[boo2x] = "\n<h1> " .* newname[boo2x] .* ": "
        newname2[boo2x] .= "</h1>\n"

        output = fill("", (size(pmid_data, 1)))

        for ix in 1:size(pmid_data, 1)
            tempx = fill("", (size(pmid_data, 2)))
            for jx in 1:size(pmid_data, 2)
                tempx[jx] = newname[jx] * (pmid_data[ix, jx]) * newname2[jx]
            end
            output[ix] = join(tempx)*"\n"
        end
        ret = join(output)

        if (writehtml)
            write_html("Reference List", ret, "test.html", true)
        end
        return(ret)
        #write_html("test", ret, "test.html", true)
    end #of Base.@ccallable function

    # """
    # Base.@ccallable function make_html_from_pmid(char1::String, writehtml::Bool = true)::String
    # Base.@ccallable function make_html_from_pmid(charx::Array{String,1}, writehtml::Bool = true)::Strin
    # Base.@ccallable function make_html_from_pmid(int::Int64, writehtml::Bool = true)::String
    # ase.@ccallable Base.@ccallable function make_html_from_pmid(int::Array{Int64,1}, writehtml::Bool = true)::String
    #
    # make html filefrom PMID and show it from dataframe
    # """
    Base.@ccallable function make_html_from_pmid(char1::String, writehtml::Bool = true)::String
        char = String.(split(char1, ","))
        charx = get_pmid_from_URL.(char)
        #charx = get_pmid_from_URL(char1)

        pmid_list_file_abs = "PMID_list_from_Julia.txt"
        pubmed_data_generated_file_abs = ""
        #for known pmid_data
        newdata= add_PMID_to_list_and_write_to_csv(charx, pmid_list_file_abs, pubmed_data_generated_file_abs)
        # newdata.FAU

        ret = make_html_from_dataframe(newdata, writehtml)
        return(ret)
        #write_html("test", ret, "test.html", true)
    end #of Base.@ccallable function

    Base.@ccallable function make_html_from_pmid(charx::Array{String,1}, writehtml::Bool = true)::String
        ret = ""
        for ix in charx
            ret = ret * make_html_from_pmid(ix, false) * "\n\n"
        end
        if (writehtml)
            write_html("Reference List", ret, "test.html", true)
        end
        return(ret)
    end

    Base.@ccallable function make_html_from_pmid(int::Int64, writehtml::Bool = true)::String
        charx = Int64ToString(int)
        ret = make_html_from_pmid(charx, writehtml)
        return( ret )
    end

    Base.@ccallable function make_html_from_pmid(int::Array{Int64,1}, writehtml::Bool = true)::String
        charx = Int64ToString.(int)
        ret = make_html_from_pmid(charx, writehtml)
        return( ret )
    end

# """
# Base.@ccallable function make_html_from_csv(csvfile::String, writehtml::Bool = true)::String
# make html file from generated CSV and show it from dataframe
# """
    Base.@ccallable function make_html_from_csv(csvfile::String, writehtml::Bool = true)::String
        try
            pmid_data = custom_CSV_read(csvfile)
            ret = make_html_from_dataframe(pmid_data, writehtml)
            return(ret)
        catch
            return("")
        end
    end #of Base.@ccallable function


# """
# Base.@ccallable function obtain_medline_from_readcube_bib(bibfile_abs::String, pmid_list_file_abs::String, pubmed_data_processed_file_abs::String)::DataFrame
#
#     # obtain and record medline dataframe from internet
#     # pmid_list_file_abs is list of pmid_data
#     # pubmed_data_processed_file_abs is csv file
# """
    Base.@ccallable function obtain_medline_from_readcube_bib(bibfile_abs::String, pmid_list_file_abs::String, pubmed_data_processed_file_abs::String)::DataFrame
        unitnum = 150;
        #obtain PMID strings joined by "," as char
        char = convert_readcube_bib(bibfile_abs, pmid_list_file_abs, unitnum, true)
        pmid_data = add_char_to_pubmed_csv(char, "")

        pmid_data = add_name_list_and_data_to_pmid_data(pmid_data)
        pmid_data = add_several_reference_string(pmid_data)

        try
            CSV.write(pubmed_data_processed_file_abs, pmid_data)
        catch
            throw("file not found: ")
        end
        return(pmid_data)
    end #of Base.@ccallable function

end  # module
