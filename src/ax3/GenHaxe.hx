package ax3;

import haxe.macro.TypedExprTools;
import ax3.ParseTree;
import ax3.TypedTree;

@:nullSafety
class GenHaxe extends PrinterBase {
	public function writeModule(m:TModule) {
		printPackage(m.pack);
		for (d in m.privateDecls) {
			printDecl(d);
		}
		printTrivia(m.eof.leadTrivia);
	}

	function printPackage(p:TPackageDecl) {
		if (p.syntax.name != null) {
			printTextWithTrivia("package", p.syntax.keyword);
			printDotPath(p.syntax.name);
			buf.add(";");
		} else {
			printTokenTrivia(p.syntax.keyword);
		}

		printTokenTrivia(p.syntax.openBrace);

		for (i in p.imports) {
			printImport(i);
		}

		for (n in p.namespaceUses) {
			printUseNamespace(n.n);
			printTokenTrivia(n.semicolon);
		}

		printDecl(p.decl);
		printTokenTrivia(p.syntax.closeBrace);
	}

	function printImport(i:TImport) {
		if (i.condCompBegin != null) printCondCompBegin(i.condCompBegin);
		printTextWithTrivia("import", i.syntax.keyword);
		printDotPath(i.syntax.path);
		if (i.syntax.wildcard != null) {
			printDot(i.syntax.wildcard.dot);
			printTextWithTrivia("*", i.syntax.wildcard.asterisk);
		}
		printSemicolon(i.syntax.semicolon);
		if (i.condCompEnd != null) printCompCondEnd(i.condCompEnd);
	}

	function printDecl(d:TDecl) {
		switch (d) {
			case TDClass(c): printClassDecl(c);
			case TDInterface(i): printInterfaceDecl(i);
			case TDVar(v): printModuleVarDecl(v);
			case TDFunction(f): printFunctionDecl(f);
			case TDNamespace(n): printNamespace(n);
		}
	}

	function printNamespace(ns:NamespaceDecl) {
		printDeclModifiers(ns.modifiers);
		printTextWithTrivia("namespace", ns.keyword);
		printTextWithTrivia(ns.name.text, ns.name);
		printSemicolon(ns.semicolon);
	}

	function printFunctionDecl(f:TFunctionDecl) {
		printMetadata(f.metadata);
		printDeclModifiers(f.modifiers);
		printTextWithTrivia("function", f.syntax.keyword);
		printTextWithTrivia(f.name, f.syntax.name);
		printSignature(f.fun.sig);
		printExpr(f.fun.expr);
	}

	function printModuleVarDecl(v:TModuleVarDecl) {
		printMetadata(v.metadata);
		printDeclModifiers(v.modifiers);
		printVarField(v);
	}

	function printInterfaceDecl(i:TInterfaceDecl) {
		printMetadata(i.metadata);
		printDeclModifiers(i.modifiers);
		printTextWithTrivia("interface", i.syntax.keyword);
		printTextWithTrivia(i.name, i.syntax.name);
		if (i.extend != null) {
			printTextWithTrivia("extends", i.extend.syntax.keyword);
			for (i in i.extend.interfaces) {
				printDotPath(i.syntax);
				if (i.comma != null) printComma(i.comma);
			}
		}
		printOpenBrace(i.syntax.openBrace);
		for (m in i.members) {
			switch (m) {
				case TIMField(f): printInterfaceField(f);
				case TIMCondCompBegin(b): printCondCompBegin(b);
				case TIMCondCompEnd(b): printCompCondEnd(b);
			}
		}
		printCloseBrace(i.syntax.closeBrace);
	}

	function printInterfaceField(f:TInterfaceField) {
		printMetadata(f.metadata);

		switch (f.kind) {
			case TIFFun(f):
				printTextWithTrivia("function", f.syntax.keyword);
				printTextWithTrivia(f.name, f.syntax.name);
				printSignature(f.sig);
			case TIFGetter(f):
				printTextWithTrivia("function", f.syntax.functionKeyword);
				printTokenTrivia(f.syntax.accessorKeyword);
				printTextWithTrivia("get_" + f.name, f.syntax.name);
				printSignature(f.sig);
			case TIFSetter(f):
				printTextWithTrivia("function", f.syntax.functionKeyword);
				printTokenTrivia(f.syntax.accessorKeyword);
				printTextWithTrivia("set_" + f.name, f.syntax.name);
				printSignature(f.sig);
		}

		printSemicolon(f.semicolon);
	}

	function printClassDecl(c:TClassDecl) {
		printMetadata(c.metadata);
		printDeclModifiers(c.modifiers);
		printTextWithTrivia("class", c.syntax.keyword);
		printTextWithTrivia(c.name, c.syntax.name);
		if (c.extend != null) {
			printTextWithTrivia("extends", c.extend.syntax.keyword);
			printDotPath(c.extend.syntax.path);
		}
		if (c.implement != null) {
			printTextWithTrivia("implements", c.implement.syntax.keyword);
			for (i in c.implement.interfaces) {
				printDotPath(i.syntax);
				if (i.comma != null) printComma(i.comma);
			}
		}
		printOpenBrace(c.syntax.openBrace);
		for (m in c.members) {
			switch (m) {
				case TMCondCompBegin(b): printCondCompBegin(b);
				case TMCondCompEnd(b): printCompCondEnd(b);
				case TMField(f): printClassField(f);
				case TMUseNamespace(n, semicolon): printUseNamespace(n); printSemicolon(semicolon);
				case TMStaticInit(i): //printExpr(i.expr);
			}
		}
		printCloseBrace(c.syntax.closeBrace);
	}

	function printCondCompBegin(e:TCondCompBegin) {
		printTokenTrivia(e.v.syntax.ns);
		printTokenTrivia(e.v.syntax.sep);
		printTextWithTrivia("#if " + e.v.ns + "_" + e.v.name, e.v.syntax.name);
		printTokenTrivia(e.openBrace);
	}

	function printCompCondEnd(e:TCondCompEnd) {
		printTextWithTrivia("#end", e.closeBrace);
	}

	function printDeclModifiers(modifiers:Array<DeclModifier>) {
		for (m in modifiers) {
			switch (m) {
				case DMPublic(t): printTokenTrivia(t);
				case DMInternal(t): printTextWithTrivia("/*internal*/", t);
				case DMFinal(t): printTextWithTrivia("@:final", t);
				case DMDynamic(t): printTextWithTrivia("/*dynamic*/", t);
			}
		}
	}

	function printClassField(f:TClassField) {
		printMetadata(f.metadata);

		if (f.namespace != null) printTextWithTrivia(f.namespace.text, f.namespace);

		for (m in f.modifiers) {
			switch (m) {
				case FMPublic(t): printTextWithTrivia("public", t);
				case FMPrivate(t): printTextWithTrivia("private", t);
				case FMProtected(t): printTextWithTrivia("/*protected*/private", t);
				case FMInternal(t): printTextWithTrivia("/*internal*/", t);
				case FMOverride(t): printTextWithTrivia("override", t);
				case FMStatic(t): printTextWithTrivia("static", t);
				case FMFinal(t): printTextWithTrivia("@:final", t);
			}
		}

		switch (f.kind) {
			case TFVar(v):
				printVarField(v);
			case TFFun(f):
				printTextWithTrivia("function", f.syntax.keyword);
				printTextWithTrivia(f.name, f.syntax.name);
				printSignature(f.fun.sig);
				printExpr(f.fun.expr);
			case TFGetter(f):
				printTextWithTrivia("function", f.syntax.functionKeyword);
				printTokenTrivia(f.syntax.accessorKeyword);
				printTextWithTrivia("get_" + f.name, f.syntax.name);
				printSignature(f.fun.sig);
				printExpr(f.fun.expr);
			case TFSetter(f):
				printTextWithTrivia("function", f.syntax.functionKeyword);
				printTokenTrivia(f.syntax.accessorKeyword);
				printTextWithTrivia("set_" + f.name, f.syntax.name);
				printSignature(f.fun.sig);
				printExpr(f.fun.expr);
		}
	}

	function printVarField(v:TVarField) {
		printVarKind(v.kind);
		for (v in v.vars) {
			printTextWithTrivia(v.name, v.syntax.name);
			if (v.syntax.type != null) {
				// printSyntaxTypeHint(v.syntax.type);
				printColon(v.syntax.type.colon);
			} else {
				buf.add(":");
			}
			printTType(v.type);
			if (v.init != null) printVarInit(v.init);
			if (v.comma != null) printComma(v.comma);
		}
		printSemicolon(v.semicolon);
	}

	function printMetadata(metas:Array<Metadata>) {
		for (m in metas) {
			printTokenTrivia(m.openBracket);
			buf.add("@:meta(");
			printTextWithTrivia(m.name.text, m.name);
			if (m.args == null) {
				buf.add("()");
			} else {
				var p = new Printer();
				p.printCallArgs(m.args);
				buf.add(p.toString());
			}
			buf.add(")");
			printTokenTrivia(m.closeBracket);
		}
	}

	function printSignature(sig:TFunctionSignature) {
		printOpenParen(sig.syntax.openParen);
		for (arg in sig.args) {
			switch (arg.kind) {
				case TArgNormal(hint, init):
					printTextWithTrivia(arg.name, arg.syntax.name);
					if (hint != null) {
						printColon(hint.colon);
					} else {
						buf.add(":");
					}
					printTType(arg.type);
					// if (hint != null) printSyntaxTypeHint(hint);
					if (init != null) printVarInit(init);

				case TArgRest(dots):
					printTextWithTrivia("...", dots);
					printTextWithTrivia(arg.name, arg.syntax.name);
			}
			if (arg.comma != null) printComma(arg.comma);
		}
		printCloseParen(sig.syntax.closeParen);
		printTypeHint(sig.ret);
	}

	function printTypeHint(hint:TTypeHint) {
		if (hint.syntax != null) {
			// printSyntaxTypeHint(hint.syntax);
			printColon(hint.syntax.colon);
		} else {
			buf.add(":");
		}
		// TODO don't forget trivia
		printTType(hint.type);
	}

	function printTType(t:TType) {
		switch t {
			case TTVoid: buf.add("Void");
			case TTAny: buf.add("Dynamic");
			case TTBoolean: buf.add("Bool");
			case TTNumber: buf.add("Float");
			case TTInt: buf.add("Int");
			case TTUint: buf.add("UInt");
			case TTString: buf.add("String");
			case TTArray: buf.add("Array<Dynamic>");
			case TTFunction: buf.add("haxe.Constraints.Function");
			case TTClass: buf.add("Class<Dynamic>");
			case TTObject: buf.add("Dynamic<Dynamic>");
			case TTXML: buf.add("flash.xml.XML");
			case TTXMLList: buf.add("flash.xml.XMLList");
			case TTRegExp: buf.add("flash.utils.RegExp");
			case TTVector(t): buf.add("flash.Vector<"); printTType(t); buf.add(">");
			case TTBuiltin: buf.add("TODO");
			case TTFun(args, ret, rest):
				if (args.length == 0) {
					buf.add("Void->");
				} else {
					for (arg in args) {
						printTType(arg);
						buf.add("->");
					}
				}
				printTType(ret);

			case TTInst(cls): buf.add(cls.name);
			case TTStatic(cls): buf.add("Class<" + cls.name + ">");
		}
	}

	function printSyntaxTypeHint(t:TypeHint) {
		printColon(t.colon);
		printSyntaxType(t.type);
	}

	function printExpr(e:TExpr) {
		switch (e.kind) {
			case TEParens(openParen, e, closeParen): printOpenParen(openParen); printExpr(e); printCloseParen(closeParen);
			case TECast(c): printCast(c);
			case TELocalFunction(f): printLocalFunction(f);
			case TELiteral(l): printLiteral(l);
			case TELocal(syntax, v): printTextWithTrivia(syntax.text, syntax);
			case TEField(object, fieldName, fieldToken): printFieldAccess(object, fieldName, fieldToken);
			case TEBuiltin(syntax, name): printTextWithTrivia(syntax.text, syntax);
			case TEDeclRef(dotPath, c): printDotPath(dotPath);
			case TECall(eobj, args): printExpr(eobj); printCallArgs(args);
			case TEArrayDecl(d): printArrayDecl(d);
			case TEVectorDecl(v): printVectorDecl(v);
			case TEReturn(keyword, e): printTextWithTrivia("return", keyword); if (e != null) printExpr(e);
			case TEThrow(keyword, e): printTextWithTrivia("throw", keyword); printExpr(e);
			case TEDelete(keyword, e): printTextWithTrivia("delete", keyword); printExpr(e);
			case TEBreak(keyword): printTextWithTrivia("break", keyword);
			case TEContinue(keyword): printTextWithTrivia("continue", keyword);
			case TEVars(kind, vars): printVars(kind, vars);
			case TEObjectDecl(o): printObjectDecl(o);
			case TEArrayAccess(a): printArrayAccess(a);
			case TEBlock(block): printBlock(block);
			case TETry(t): printTry(t);
			case TEVector(syntax, type):
				buf.add("flash.Vector<");
				printTType(type);
				buf.add(">");
				// printVectorSyntax(syntax);

			case TETernary(t): printTernary(t);
			case TEIf(i): printIf(i);
			case TEWhile(w): printWhile(w);
			case TEDoWhile(w): printDoWhile(w);
			case TEFor(f): printFor(f);
			case TEForIn(f): printForIn(f);
			case TEForEach(f): printForEach(f);
			case TEBinop(a, op, b): printBinop(a, op, b);
			case TEPreUnop(op, e): printPreUnop(op, e);
			case TEPostUnop(e, op): printPostUnop(e, op);
			case TEAs(e, keyword, type): printAs(e, keyword, type);
			case TESwitch(s): printSwitch(s);
			case TENew(keyword, eclass, args): printNew(keyword, eclass, args);
			case TECondCompValue(v): printCondCompVar(v);
			case TECondCompBlock(v, expr): printCondCompBlock(v, expr);
			case TEXmlChild(x): printXmlChild(x);
			case TEXmlAttr(x): printXmlAttr(x);
			case TEXmlAttrExpr(x): printXmlAttrExpr(x);
			case TEXmlDescend(x): printXmlDescend(x);
			case TEUseNamespace(ns): printUseNamespace(ns);
		}
	}

	function printAs(e:TExpr, keyword:Token, type:TTypeRef) {
		printTrivia(TypedTreeTools.removeLeadingTrivia(e));
		buf.add("Std.instance(");
		printExpr(e);
		printTextWithTrivia(",", keyword);
		printTType(type.type);
		// printSyntaxType(type.syntax);
		buf.add(")");
	}

	function printCast(c:TCast) {
		printDotPath(c.syntax.path);
		printOpenParen(c.syntax.openParen);
		printExpr(c.expr);
		printCloseParen(c.syntax.closeParen);
	}

	function printLocalFunction(f:TLocalFunction) {
		printTextWithTrivia("function", f.syntax.keyword);
		if (f.name != null) printTextWithTrivia(f.name.name, f.name.syntax);
		printSignature(f.fun.sig);
		printExpr(f.fun.expr);
	}

	function printXmlDescend(x:TXmlDescend) {
		printExpr(x.eobj);
		printTextWithTrivia("..", x.syntax.dotDot);
		printTextWithTrivia(x.name, x.syntax.name);
	}

	function printXmlChild(x:TXmlChild) {
		printExpr(x.eobj);
		printDot(x.syntax.dot);
		printTextWithTrivia(x.name, x.syntax.name);
	}

	function printXmlAttr(x:TXmlAttr) {
		printExpr(x.eobj);
		printDot(x.syntax.dot);
		printTextWithTrivia("@", x.syntax.at);
		printTextWithTrivia(x.name, x.syntax.name);
	}

	function printXmlAttrExpr(x:TXmlAttrExpr) {
		printExpr(x.eobj);
		printDot(x.syntax.dot);
		printTextWithTrivia("@", x.syntax.at);
		printOpenBracket(x.syntax.openBracket);
		printExpr(x.eattr);
		printCloseBracket(x.syntax.closeBracket);
	}

	function printSwitch(s:TSwitch) {
		printTextWithTrivia("switch", s.syntax.keyword);
		printOpenParen(s.syntax.openParen);
		printExpr(s.subj);
		printCloseParen(s.syntax.closeParen);
		printOpenBrace(s.syntax.openBrace);
		for (c in s.cases) {
			printTextWithTrivia("case", c.syntax.keyword);
			printExpr(c.value);
			printColon(c.syntax.colon);
			for (e in c.body) {
				printBlockExpr(e);
			}
		}
		if (s.def != null) {
			printTextWithTrivia("default", s.def.syntax.keyword);
			printColon(s.def.syntax.colon);
			for (e in s.def.body) {
				printBlockExpr(e);
			}
		}
		printCloseBrace(s.syntax.closeBrace);
	}

	function printVectorSyntax(syntax:VectorSyntax) {
		printTextWithTrivia("Vector", syntax.name);
		printDot(syntax.dot);
		printTypeParam(syntax.t);
	}

	function printTypeParam(t:TypeParam) {
		printTextWithTrivia("<", t.lt);
		printSyntaxType(t.type);
		printTextWithTrivia(">", t.gt);
	}

	function printSyntaxType(t:SyntaxType) {
		switch (t) {
			case TAny(star): printTextWithTrivia("*", star);
			case TPath(path): printDotPath(path);
			case TVector(v): printVectorSyntax(v);
		}
	}

	function printCondCompBlock(v:TCondCompVar, expr:TExpr) {
		printTokenTrivia(v.syntax.ns);
		printTokenTrivia(v.syntax.sep);
		printTextWithTrivia("#if " + v.ns + "_" + v.name, v.syntax.name);
		printExpr(expr);
		buf.add("#end");
	}

	function printCondCompVar(v:TCondCompVar) {
		printTokenTrivia(v.syntax.ns);
		printTokenTrivia(v.syntax.sep);
		buf.add(v.ns + "_" + v.name);
		printTokenTrivia(v.syntax.name);
	}

	function printUseNamespace(ns:UseNamespace) {
		printTextWithTrivia("/*use*/", ns.useKeyword);
		printTextWithTrivia("/*namespace*/", ns.namespaceKeyword);
		printTextWithTrivia("/*" + ns.name.text + "*/", ns.name);
	}

	function printTry(t:TTry) {
		printTextWithTrivia("try", t.keyword);
		printExpr(t.expr);
		for (c in t.catches) {
			printTextWithTrivia("catch", c.syntax.keyword);
			printOpenParen(c.syntax.openParen);
			printTextWithTrivia(c.v.name, c.syntax.name);
			printColon(c.syntax.type.colon);
			// printSyntaxType(c.syntax.type.type);
			printTType(c.v.type);
			printCloseParen(c.syntax.closeParen);
			printExpr(c.expr);
		}
	}

	function printWhile(w:TWhile) {
		printTextWithTrivia("while", w.syntax.keyword);
		printOpenParen(w.syntax.openParen);
		printExpr(w.cond);
		printCloseParen(w.syntax.closeParen);
		printExpr(w.body);
	}

	function printDoWhile(w:TDoWhile) {
		printTextWithTrivia("do", w.syntax.doKeyword);
		printExpr(w.body);
		printTextWithTrivia("while", w.syntax.whileKeyword);
		printOpenParen(w.syntax.openParen);
		printExpr(w.cond);
		printCloseParen(w.syntax.closeParen);
	}

	function printFor(f:TFor) {
		return buf.add("{}");
		printTextWithTrivia("for", f.syntax.keyword);
		printOpenParen(f.syntax.openParen);
		if (f.einit != null) printExpr(f.einit);
		printSemicolon(f.syntax.initSep);
		if (f.econd != null) printExpr(f.econd);
		printSemicolon(f.syntax.condSep);
		if (f.eincr != null) printExpr(f.eincr);
		printCloseParen(f.syntax.closeParen);
		printExpr(f.body);
	}

	function printForIn(f:TForIn) {
		return buf.add("{}");
		printTextWithTrivia("for", f.syntax.forKeyword);
		printOpenParen(f.syntax.openParen);
		printForInIter(f.iter);
		printCloseParen(f.syntax.closeParen);
		printExpr(f.body);
	}

	function printForEach(f:TForEach) {
		return buf.add("{}");
		printTextWithTrivia("for", f.syntax.forKeyword);
		printTextWithTrivia("each", f.syntax.eachKeyword);
		printOpenParen(f.syntax.openParen);
		printForInIter(f.iter);
		printCloseParen(f.syntax.closeParen);
		printExpr(f.body);
	}

	function printForInIter(i:TForInIter) {
		printExpr(i.eit);
		printTextWithTrivia("in", i.inKeyword);
		printExpr(i.eobj);
	}

	function printNew(keyword:Token, eclass:TExpr, args:Null<TCallArgs>) {
		printTextWithTrivia("new", keyword);
		switch (eclass.kind) {
			case TEDeclRef(_): printExpr(eclass);
			case _: buf.add("/*local*/String");
		}
		// printExpr(eclass);
		if (args != null) printCallArgs(args) else buf.add("()");
	}

	function printVectorDecl(d:TVectorDecl) {
		printTextWithTrivia("new", d.syntax.newKeyword);
		printTypeParam(d.syntax.typeParam);
		printArrayDecl(d.elements);
	}

	function printArrayDecl(d:TArrayDecl) {
		printOpenBracket(d.syntax.openBracket);
		for (e in d.elements) {
			printExpr(e.expr);
			if (e.comma != null) printComma(e.comma);
		}
		printCloseBracket(d.syntax.closeBracket);
	}

	function printCallArgs(args:TCallArgs) {
		printOpenParen(args.openParen);
		for (a in args.args) {
			printExpr(a.expr);
			if (a.comma != null) printComma(a.comma);
		}
		printCloseParen(args.closeParen);
	}

	function printTernary(t:TTernary) {
		printExpr(t.econd);
		printTextWithTrivia("?", t.syntax.question);
		printExpr(t.ethen);
		printColon(t.syntax.colon);
		printExpr(t.eelse);
	}

	function printIf(i:TIf) {
		printTextWithTrivia("if", i.syntax.keyword);
		printOpenParen(i.syntax.openParen);
		printExpr(i.econd);
		printCloseParen(i.syntax.closeParen);
		printExpr(i.ethen);
		if (i.eelse != null) {
			printTextWithTrivia("else", i.eelse.keyword);
			printExpr(i.eelse.expr);
		}
	}

	function printPreUnop(op:PreUnop, e:TExpr) {
		switch (op) {
			case PreNot(t): printTextWithTrivia("!", t);
			case PreNeg(t): printTextWithTrivia("-", t);
			case PreIncr(t): printTextWithTrivia("++", t);
			case PreDecr(t): printTextWithTrivia("--", t);
			case PreBitNeg(t): printTextWithTrivia("~", t);
		}
		printExpr(e);
	}

	function printPostUnop(e:TExpr, op:PostUnop) {
		printExpr(e);
		switch (op) {
			case PostIncr(t): printTextWithTrivia("++", t);
			case PostDecr(t): printTextWithTrivia("--", t);
		}
	}

	function printBinop(a:TExpr, op:Binop, b:TExpr) {
		printExpr(a);
		switch (op) {
			case OpAdd(t): printTextWithTrivia("+", t);
			case OpSub(t): printTextWithTrivia("-", t);
			case OpDiv(t): printTextWithTrivia("/", t);
			case OpMul(t): printTextWithTrivia("*", t);
			case OpMod(t): printTextWithTrivia("%", t);
			case OpAssign(t): printTextWithTrivia("=", t);
			case OpAssignAdd(t): printTextWithTrivia("+=", t);
			case OpAssignSub(t): printTextWithTrivia("-=", t);
			case OpAssignMul(t): printTextWithTrivia("*=", t);
			case OpAssignDiv(t): printTextWithTrivia("/=", t);
			case OpAssignMod(t): printTextWithTrivia("%=", t);
			case OpAssignAnd(t): printTextWithTrivia("&&=", t);
			case OpAssignOr(t): printTextWithTrivia("||=", t);
			case OpAssignBitAnd(t): printTextWithTrivia("&=", t);
			case OpAssignBitOr(t): printTextWithTrivia("|=", t);
			case OpAssignBitXor(t): printTextWithTrivia("^=", t);
			case OpAssignShl(t): printTextWithTrivia("<<=", t);
			case OpAssignShr(t): printTextWithTrivia(">>=", t);
			case OpAssignUshr(t): printTextWithTrivia(">>>=", t);
			case OpEquals(t): printTextWithTrivia("==", t);
			case OpNotEquals(t): printTextWithTrivia("!=", t);
			case OpStrictEquals(t): printTextWithTrivia("===", t);
			case OpNotStrictEquals(t): printTextWithTrivia("!==", t);
			case OpGt(t): printTextWithTrivia(">", t);
			case OpGte(t): printTextWithTrivia(">=", t);
			case OpLt(t): printTextWithTrivia("<", t);
			case OpLte(t): printTextWithTrivia("<=", t);
			case OpIn(t): printTextWithTrivia("in", t);
			case OpIs(t): printTextWithTrivia("is", t);
			case OpAnd(t): printTextWithTrivia("&&", t);
			case OpOr(t): printTextWithTrivia("||", t);
			case OpShl(t): printTextWithTrivia("<<", t);
			case OpShr(t): printTextWithTrivia(">>", t);
			case OpUshr(t): printTextWithTrivia(">>>", t);
			case OpBitAnd(t): printTextWithTrivia("&", t);
			case OpBitOr(t): printTextWithTrivia("|", t);
			case OpBitXor(t): printTextWithTrivia("^", t);
			case OpComma(t): printTextWithTrivia(",", t);
		}
		printExpr(b);
	}

	function printArrayAccess(a:TArrayAccess) {
		printExpr(a.eobj);
		printOpenBracket(a.syntax.openBracket);
		printExpr(a.eindex);
		printCloseBracket(a.syntax.closeBracket);
	}

	function printVarKind(kind:VarDeclKind) {
		switch (kind) {
			case VVar(t): printTextWithTrivia("var", t);
			case VConst(t): printTextWithTrivia("/*final*/var", t);
		}
	}

	function printVars(kind:VarDeclKind, vars:Array<TVarDecl>) {
		printVarKind(kind);
		for (v in vars) {
			printTextWithTrivia(v.v.name, v.syntax.name);
			if (v.syntax.type != null) {
				printColon(v.syntax.type.colon);
				// printSyntaxTypeHint(v.syntax.type);
			} else {
				buf.add(":");
			}
			printTType(v.v.type);
			if (v.init != null) printVarInit(v.init);
			if (v.comma != null) printComma(v.comma);
		}
	}

	function printVarInit(init:TVarInit) {
		printTextWithTrivia("=", init.equals);
		printExpr(init.expr);
	}

	function printObjectDecl(o:TObjectDecl) {
		printOpenBrace(o.syntax.openBrace);
		for (f in o.fields) {
			printTextWithTrivia(f.name, f.syntax.name); // TODO: quoted fields
			printColon(f.syntax.colon);
			printExpr(f.expr);
			if (f.syntax.comma != null) printComma(f.syntax.comma);
		}
		printCloseBrace(o.syntax.closeBrace);
	}

	function printFieldAccess(obj:TFieldObject, name:String, token:Token) {
		switch (obj.kind) {
			case TOExplicit(dot, e):
				printExpr(e);
				printDot(dot);
			case TOImplicitThis(_):
			case TOImplicitClass(_):
		}
		printTextWithTrivia(name, token);
	}

	function printLiteral(l:TLiteral) {
		switch (l) {
			case TLSuper(syntax): printTextWithTrivia("super", syntax);
			case TLThis(syntax): printTextWithTrivia("this", syntax);
			case TLBool(syntax): printTextWithTrivia(syntax.text, syntax);
			case TLNull(syntax): printTextWithTrivia("null", syntax);
			case TLUndefined(syntax): printTextWithTrivia("undefined", syntax);
			case TLInt(syntax): printTextWithTrivia(syntax.text, syntax);
			case TLNumber(syntax): printTextWithTrivia(syntax.text, syntax);
			case TLString(syntax): printTextWithTrivia(syntax.text, syntax);
			case TLRegExp(syntax): printTextWithTrivia("~"+syntax.text, syntax);
		}
	}

	function printBlock(block:TBlock) {
		printOpenBrace(block.syntax.openBrace);
		for (e in block.exprs) {
			printBlockExpr(e);
		}
		printCloseBrace(block.syntax.closeBrace);
	}

	function printBlockExpr(e:TBlockExpr) {
		printExpr(e.expr);
		if (e.semicolon != null) {
			printSemicolon(e.semicolon);
		} else if (!e.expr.kind.match(TEBlock(_) | TECondCompBlock(_))) {
			buf.add(";");
		}
	}

	inline function printTokenTrivia(t:Token) {
		printTrivia(t.leadTrivia);
		printTrivia(t.trailTrivia);
	}
}