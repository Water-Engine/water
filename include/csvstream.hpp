#pragma once

#include <iostream>
#include <fstream>
#include <sstream>
#include <cassert>
#include <string>
#include <vector>
#include <map>
#include <regex>
#include <exception>

class csvstream_exception : public std::exception
{
public:
    const char *what() const noexcept override
    {
        return msg.c_str();
    }
    const std::string msg;
    csvstream_exception(const std::string &msg) : msg(msg) {};
};

class csvstream
{
private:
    std::string filename;
    std::ifstream fin;
    std::istream &is;

    char delimiter;
    bool strict;

    size_t line_no;
    std::vector<std::string> header;

    csvstream(const csvstream &);
public:
    csvstream(const std::string &filename, char delimiter = ',', bool strict = true)
        : filename(filename),
          is(fin),
          delimiter(delimiter),
          strict(strict),
          line_no(0)
    {

        fin.open(filename.c_str());
        if (!fin.is_open())
        {
            throw csvstream_exception("Error opening file: " + filename);
        }

        read_header();
    }

    csvstream(std::istream &is, char delimiter = ',', bool strict = true)
        : filename("[no filename]"),
          is(is),
          delimiter(delimiter),
          strict(strict),
          line_no(0)
    {
        read_header();
    }

    ~csvstream()
    {
        if (fin.is_open())
            fin.close();
    }

    explicit operator bool() const
    {
        return static_cast<bool>(is);
    }

    std::vector<std::string> getheader() const
    {
        return header;
    }

    csvstream &operator>>(std::map<std::string, std::string> &row)
    {
        return extract_row(row);
    }

    csvstream &operator>>(std::vector<std::pair<std::string, std::string>> &row)
    {
        return extract_row(row);
    }

    static bool read_csv_line(std::istream &is,
                              std::vector<std::string> &data,
                              char delimiter)
    {

        data.clear();
        data.push_back(std::string());

        char c = '\0';
        enum State
        {
            BEGIN,
            QUOTED,
            QUOTED_ESCAPED,
            UNQUOTED,
            UNQUOTED_ESCAPED,
            END
        };
        State state = BEGIN;
        while (is.get(c))
        {
            switch (state)
            {
            case BEGIN:
                state = UNQUOTED;

#if __GNUG__ && __GNUC__ >= 7
                [[fallthrough]];
#endif

            case UNQUOTED:
                if (c == '"')
                {
                    state = QUOTED;
                }
                else if (c == '\\')
                {
                    state = UNQUOTED_ESCAPED;
                    data.back() += c;
                }
                else if (c == delimiter)
                {
                    data.push_back("");
                }
                else if (c == '\n' || c == '\r')
                {
                    state = END;
                }
                else
                {
                    data.back() += c;
                }
                break;

            case UNQUOTED_ESCAPED:
                data.back() += c;
                state = UNQUOTED;
                break;

            case QUOTED:
                if (c == '"')
                {
                    state = UNQUOTED;
                }
                else if (c == '\\')
                {
                    state = QUOTED_ESCAPED;
                    data.back() += c;
                }
                else
                {
                    data.back() += c;
                }
                break;

            case QUOTED_ESCAPED:
                data.back() += c;
                state = QUOTED;
                break;

            case END:
                if (c == '\n')
                {
                }
                else
                {
                    is.unget();
                }

                goto multilevel_break;
                break;

            default:
                assert(0);
                throw state;

            }
        }

    multilevel_break:
        if (state != BEGIN)
        {
            is.clear();
        }

        return static_cast<bool>(is);
    }

    void read_header()
    {
        if (!read_csv_line(is, header, delimiter))
        {
            throw csvstream_exception("error reading header");
        }
    }

    csvstream &extract_row(std::map<std::string, std::string> &row)
    {
        row.clear();

        std::vector<std::string> data;
        if (!read_csv_line(is, data, delimiter))
            return *this;
        line_no += 1;

        if (!strict)
        {
            data.resize(header.size());
        }

        if (data.size() != header.size())
        {
            auto msg = "Number of items in row does not match header. " +
                       filename + ":L" + std::to_string(line_no) + " " +
                       "header.size() = " + std::to_string(header.size()) + " " +
                       "row.size() = " + std::to_string(data.size()) + " ";
            throw csvstream_exception(msg);
        }

        for (size_t i = 0; i < data.size(); ++i)
        {
            row[header[i]] = data[i];
        }

        return *this;
    }

    csvstream &extract_row(std::vector<std::pair<std::string, std::string>> &row)
    {
        row.clear();
        row.resize(header.size());
        std::vector<std::string> data;
        if (!read_csv_line(is, data, delimiter))
            return *this;
        line_no += 1;

        if (!strict)
        {
            data.resize(header.size());
        }

        if (row.size() != header.size())
        {
            auto msg = "Number of items in row does not match header. " +
                       filename + ":L" + std::to_string(line_no) + " " +
                       "header.size() = " + std::to_string(header.size()) + " " +
                       "row.size() = " + std::to_string(row.size()) + " ";
            throw csvstream_exception(msg);
        }

        for (size_t i = 0; i < data.size(); ++i)
        {
            row[i] = make_pair(header[i], data[i]);
        }

        return *this;
    }
};
