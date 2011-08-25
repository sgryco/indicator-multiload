/******************************************************************************
 * Copyright (C) 2011  Michael Hofmann <mh21@piware.de>                       *
 *                                                                            *
 * This program is free software; you can redistribute it and/or modify       *
 * it under the terms of the GNU General Public License as published by       *
 * the Free Software Foundation; either version 3 of the License, or          *
 * (at your option) any later version.                                        *
 *                                                                            *
 * This program is distributed in the hope that it will be useful,            *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of             *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              *
 * GNU General Public License for more details.                               *
 *                                                                            *
 * You should have received a copy of the GNU General Public License along    *
 * with this program; if not, write to the Free Software Foundation, Inc.,    *
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.                *
 ******************************************************************************/

internal class ExpressionTokenizer {
    private char *last;
    private char *current;
    private string[] result;

    public string[] tokenize(string expression) {
        this.result = null;
        this.last = null;
        int level = 0;
        bool inexpression = false;
        for (this.current = expression; *this.current != '\0';
                this.current = this.current + 1) {
            if (!inexpression) {
                if (*this.current == '$') {
                    this.save();
                    this.add(*this.current);
                    inexpression = true;
                } else {
                    this.expand();
                }
            } else {
                if (level == 0) {
                    if (this.isvariable()) {
                        this.expand();
                    } else if (this.last == null && *this.current == '(') {
                        this.add(*this.current);
                        ++level;
                    } else {
                        this.add('(');
                        this.save();
                        this.add(')');
                        this.expand();
                        inexpression = false;
                    }
                } else {
                    if (*this.current == '(') {
                        this.save();
                        this.add(*this.current);
                        ++level;
                    } else if (*this.current == ')') {
                        this.save();
                        this.add(*this.current);
                        --level;
                        if (level == 0)
                            inexpression = false;
                    } else if (this.isspace()) {
                        this.save();
                    } else if (!this.isvariable()) {
                        this.save();
                        this.add(*this.current);
                    } else {
                        this.expand();
                    }
                }
            }
        }
        this.save();
        return this.result;
    }

    private void expand() {
        if (this.last == null)
            this.last = this.current;
        // stderr.printf("Expanding token to '%s'\n", strndup(last, current - last + 1));
    }

    private void save() {
        if (this.last != null) {
            var token = strndup(this.last, this.current - this.last);
            // stderr.printf("Saving token '%s'\n", token);
            this.result += token;
            this.last = null;
        } else {
            // stderr.printf("Not saving empty token\n");
        }
    }

    private void add(char what) {
        var token = what.to_string();
        // stderr.printf("Adding token '%s'\n", token);
        this.result += token;
    }

    private bool isspace() {
        return *this.current == ' ';
    }

    private bool isvariable() {
        return
            *this.current >= 'a' && *this.current <= 'z' ||
            *this.current >= '0' && *this.current <= '9' ||
            *this.current == '.';
    }
}

internal class ExpressionEvaluator {
    private Providers providers;

    private uint index;
    private string[] tokens;

    public ExpressionEvaluator(Providers providers) {
        this.providers = providers;
    }

    private static Error error(uint index, string message) {
        return new Error(Quark.from_string("expression-error-quark"),
                (int)index, "%s", message);
    }

    private string parens_or_identifier() throws Error {
        if (this.index >= this.tokens.length)
            throw error(this.index, "empty expression");
        if (this.tokens[this.index] == "(")
            return parens();
        return identifier();
    }

    private string times() throws Error {
        string result = null;
        bool div = false;
        for (;;) {
            if (this.index >= this.tokens.length)
                throw error(this.index, "expression expected");
            var value = parens_or_identifier();
            if (result == null)
                result = value;
            else if (!div)
                result = (double.parse(result) * double.parse(value)).to_string();
            else
                result = (double.parse(result) / double.parse(value)).to_string();
            if (this.index >= this.tokens.length)
                return result;
            switch (this.tokens[this.index]) {
            case "*":
                div = false;
                ++this.index;
                continue;
            case "/":
                div = true;
                ++this.index;
                continue;
            default:
                return result;
            }
        }
    }

    private string plus() throws Error {
        string result = null;
        bool minus = false;
        for (;;) {
            if (this.index >= this.tokens.length)
                throw error(this.index, "expression expected");
            var value = times();
            if (result == null)
                result = value;
            else if (!minus)
                result = (double.parse(result) + double.parse(value)).to_string();
            else
                result = (double.parse(result) - double.parse(value)).to_string();
            if (this.index >= this.tokens.length)
                return result;
            switch (this.tokens[this.index]) {
            case "+":
                minus = false;
                ++this.index;
                continue;
            case "-":
                minus = true;
                ++this.index;
                continue;
            default:
                return result;
            }
        }
    }

    private string parens() throws Error {
        if (this.index >= this.tokens.length ||
                this.tokens[this.index] != "(")
            throw error(this.index, "'(' expected");
        ++this.index;
        var result = plus();
        if (this.index >= this.tokens.length ||
                this.tokens[this.index] != ")")
            throw error(this.index, "')' expected");
        ++this.index;
        return result;
    }

    private string[] params() throws Error {
        string[] result = null;
        if (this.index >= this.tokens.length ||
                this.tokens[this.index] != "(")
            throw error(this.index, "'(' expected");
        ++this.index;
        if (this.index >= this.tokens.length)
            throw error(this.index, "parameters expected");
        if (this.tokens[this.index] != ")") {
            for (;;) {
                result += plus();
                if (this.index >= this.tokens.length)
                    throw error(this.index, "')' expected");
                if (this.tokens[this.index] != ",")
                    break;
                ++this.index;
            }
        }
        if (this.index >= this.tokens.length ||
                this.tokens[this.index] != ")")
            throw error(this.index, "')' expected");
        ++this.index;
        return result;
    }

    private string identifier() throws Error {
        if (this.index >= this.tokens.length)
            throw error(this.index, "identifier expected");
        double sign = 1;
        if (this.tokens[this.index] == "+") {
            ++this.index;
            if (this.index >= this.tokens.length)
                throw error(this.index, "identifier expected");
        } else if (this.tokens[this.index] == "-") {
            sign = -1.0;
            ++this.index;
            if (this.index >= this.tokens.length)
                throw error(this.index, "identifier expected");
        }
        var token = this.tokens[this.index];
        if (token.length > 0 && (token[0] >= '0' && token[0] <= '9' || token[0] == '.')) {
            ++this.index;
            if (sign == -1)
                return "-" + token;
            return token;
        }
        var varparts = token.split(".");
        var nameindex = this.index;
        ++this.index;
        switch (varparts.length) {
        case 1:
            var function = varparts[0];
            var parameters = params();
            switch (function) {
            case "decimals":
                if (parameters.length < 2)
                    throw error(this.index, "at least two parameters expected");
                return "%.*f".printf(int.parse(parameters[1]), sign * double.parse(parameters[0]));
            case "size":
                if (parameters.length < 1)
                    throw error(this.index, "at least one parameter expected");
                return Utils.format_size(sign * double.parse(parameters[0]));
            case "speed":
                if (parameters.length < 1)
                    throw error(this.index, "at least one parameter expected");
                return Utils.format_speed(sign * double.parse(parameters[0]));
            case "percent":
                if (parameters.length < 1)
                    throw error(this.index, "at least one parameter expected");
                return _("%u%%").printf
                    ((uint) Math.round(100 * sign * double.parse(parameters[0])));
            default:
                throw error(nameindex, "unknown function");
            }
        case 2:
            foreach (var provider in this.providers.providers) {
                if (provider.id != varparts[0])
                    continue;
                for (uint j = 0, jsize = provider.keys.length; j < jsize; ++j) {
                    if (provider.keys[j] != varparts[1])
                        continue;
                    return (sign * provider.values[j]).to_string();
                }
            }
            throw error(nameindex, "unknown variable");
        default:
            throw error(nameindex, "too many identifier parts");
        }
    }

    private string text() throws Error {
        string[] result = {};
        while (this.index < this.tokens.length) {
            string current = this.tokens[this.index];
            if (current == "$") {
                ++this.index;
                result += parens_or_identifier();
            } else {
                result += current;
                ++this.index;
            }
        }

        return string.joinv("", result);
    }

    public string evaluate(string[] tokens) {
        this.index = 0;
        this.tokens = tokens;
        try {
            return text();
        } catch (Error e) {
            stderr.printf("Expression error: %s\n", e.message);
            string errormessage = "";
            int errorpos = -1;
            for (uint i = 0, isize = this.tokens.length; i < isize; ++i) {
                if (e.code == i)
                    errorpos = errormessage.length;
                errormessage += " " + this.tokens[i];
            }
            if (errorpos < 0)
                errorpos = errormessage.length;
            stderr.printf("%s\n%s^\n", errormessage, string.nfill(errorpos, '-'));
            return "";
        }
    }
}

public class ExpressionParser : Object {
    private Providers providers;

    public ExpressionParser(Providers providers) {
        this.providers = providers;
    }

    public string[] tokenize(string expression) {
        return new ExpressionTokenizer().tokenize(expression);
    }

    public string evaluate(string[] tokens) {
        return new ExpressionEvaluator(this.providers).evaluate(tokens);
    }

    public string parse(string expression) {
        return evaluate(tokenize(expression));
    }
}
