/*
* Copyright (C) 2020 Grakn Labs
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 */

package grakn.verification.tools.operator;

import graql.lang.pattern.Conjunction;
import graql.lang.pattern.Pattern;

import java.util.stream.Stream;


/**
 * Interface for defining Pattern operators. The application of an operator O on an input pattern P
 * results in a set of patterns P' such that:
 *
 * {P'} = O P
 *
 */
public interface Operator {

    /**
     * @param src pattern to be transformed
     * @ctx type context for patterns
     * @return set of patterns resulting from operator application
     */
    Stream<? extends Conjunction<? extends Pattern>> apply(Conjunction<?> src, TypeContext ctx);
}
