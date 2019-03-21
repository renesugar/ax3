package ax3.filters;

class RewriteDelete extends AbstractFilter {
	static final eDeleteField = mkBuiltin("Reflect.deleteField", TTFun([TTAny, TTString], TTBoolean));

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch (e.kind) {
			case TEDelete(keyword, eobj):
				switch eobj.kind {
					case TEArrayAccess(a) | TEParens(_, {kind: TEArrayAccess(a)}, _):
						rewrite(keyword, a, eobj, e);

					case _:
						reportError(exprPos(eobj), "Unsupported `delete` operation");
						e;
				}
			case _:
				e;
		}
	}

	function rewrite(deleteKeyword:Token, a:TArrayAccess, eDeleteObj:TExpr, eDelete:TExpr):TExpr {
		// TODO: trivia \o/
		return switch [a.eobj.type, a.eindex.type] {
			case [TTDictionary(keyType, _), _]: // TODO: it should really be FQN flash.utils.Dictionary here, but it's annoying
				processLeadingToken(function(t) {
					t.leadTrivia = deleteKeyword.leadTrivia.concat(t.leadTrivia);
				}, a.eobj);

				var eRemoveField = mk(TEField({kind: TOExplicit(mkDot(), a.eobj), type: a.eobj.type}, "remove", mkIdent("remove")), TTFunction, TTFunction);
				mkCall(eRemoveField, [a.eindex.with(expectedType = keyType)], TTBoolean);

			case [TTObject, _] | [_, TTString]:
				// make sure the expected type is string so further filters add the cast
				var eindex = if (a.eindex.type != TTString) a.eindex.with(expectedType = TTString) else a.eindex;
				mkCall(eDeleteField, [a.eobj, eindex]);

			case [TTArray(_), TTInt | TTUint]:
				reportError(exprPos(a.eindex), 'delete on array?');

				if (eDelete.expectedType == TTBoolean) {
					throw "TODO"; // always true probably
				}

				processLeadingToken(function(t) {
					t.leadTrivia = deleteKeyword.leadTrivia.concat(t.leadTrivia);
				}, eDeleteObj);

				mk(TEBinop(eDeleteObj, OpAssign(new Token(0, TkEquals, "=", [], [])), mkNullExpr()), TTVoid, TTVoid);

			case _:
				reportError(exprPos(a.eindex), 'Unknown index type: ' + a.eindex.type.getName());
				throw "assert";
		}
	}
}