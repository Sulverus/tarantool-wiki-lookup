#!/usr/bin/python

import io, json, sys
import mysql.connector as mariadb

stat = {
    "page_id_max": 0,
    "cl_from_max": 0,

    "skipped_invalid_sql_result": 0,
    "skipped_by_filter": 0,
    "cl_from_not_in_pages": 0,

    "page_ids": 0,
    "cl_froms": 0
}

params = {
    "user": "root",
    "password": "",
    "database": "wiki",

    "out_file": "out.json",
    "out_file_buf_size": 65536*12,

    "offset": 0,
    "end_offset": 1000000,

    "all_in_memory": False
}

def go():

    # read_args()

    connection = mariadb.connect(user = params["user"],
                                 password = params["password"],
                                 database = params["database"])
    cursor = connection.cursor()

    cl_from_max = 0
    ##
    cursor.execute(
        "select cl_from from categorylinks order by cl_from desc limit 0,1")
    for cl_from in cursor:
        cl_from_max = cl_from[0]
        break
    stat["cl_from_max"] = cl_from_max

    ##
    page_id_max = 0
    cursor.execute("select page_id from page order by page_id desc limit 0,1")
    for page_id in cursor:
        page_id_max = page_id[0]
        break
    stat["page_id_max"] = page_id_max

    ##
    out = open(params["out_file"], "w", params["out_file_buf_size"])
    (pages, offset, end_offset) = ({}, params["offset"], params["end_offset"])

    while True:

        print "select -> offset: {0}, end_offset: {1}".format(
            offset, end_offset)

        cursor.execute(
                "select page_id, page_namespace, page_title"
                " from page"
                " where page_id between %s and %s",
                (offset, end_offset))

        for page_id, page_namespace, page_title_raw in cursor:

            page_title = page_title_raw.decode("utf-8")
            if page_id == None or page_namespace == None or page_title == None:
                stat["skipped_invalid_sql_result"] += 1
                continue

            if len(page_title) > 0 and page_title[0] == "!":
                stat["skipped_by_filter"] += 1
                continue

            stat["page_ids"] += 1
            pages[page_id] = [page_id, page_namespace, page_title, []]

        if offset <= cl_from_max:

            cursor.execute(
                    "select cl_from, cl_to from categorylinks"
                    " where cl_from between %s and %s",
                    (offset, end_offset))

            for cl_from, cl_to_raw in cursor:

                cl_to = cl_to_raw.decode("utf-8")
                if cl_from == None or cl_to == None:
                    stat["skipped_invalid_sql_result"] += 1

                stat["cl_froms"] += 1
                if cl_from in pages:
                    pages[cl_from][3].append(cl_to)
                else:
                    stat["cl_from_not_in_pages"] += 1

        ###
        offset = end_offset + 1
        end_offset = end_offset + params["end_offset"] + 1

        if not params["all_in_memory"]:
            for page in pages:
                json.dump(
                    { "method": "load", "id": 0, "params": pages[page] },
                    out)
                out.write("\n")
            pages = {}
            out.flush()

        if offset > page_id_max:
            print "done ... flushing result"
            if params["all_in_memory"]:
                for page in pages:
                    json.dump(
                        { "method": "load", "id": 0, "params": pages[page] },
                        out)
                    out.write("\n")
            break

    print "Stat: ", stat

    out.close()

####
## Entry
if __name__ == "__main__":
    go()

