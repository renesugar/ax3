package ax3.filters;

import ax3.ParseTree.Binop;

class RewriteAndOrAssign extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEBinop(a, OpAssignOp(aop = (AOpAnd(_) | AOpOr(_))), b):
				if (!canBeRepeated(a)) {
					throwError(exprPos(a), "condition expr for `||=` and `&&=` must be safe to repeat");
				}

				var op:Binop = switch aop {
					case AOpAnd(t): OpAnd(new Token(0, TkAmpersandAmpersand, "&&", t.leadTrivia, t.trailTrivia));
					case AOpOr(t): OpOr(new Token(0, TkPipePipe, "||", t.leadTrivia, t.trailTrivia));
					case _: throw "assert";
				}
				var eValue = mk(TEBinop(a, op, b), a.type, a.expectedType);

				e.with(kind = TEBinop(
					a,
					OpAssign(new Token(0, TkEquals, "=", [], [whitespace])),
					eValue
				));

			case _:
				e;
		}
	}
}