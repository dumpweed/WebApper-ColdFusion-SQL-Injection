<!---
_ParameterizeQueries.cfm v1.5 (20080721)

Written by Daryl Banttari dbanttari@gmail.com
RELEASED TO THE PUBLIC DOMAIN.  But feel free to credit me with original authorship if you release it with modifications.


Purpose:

	Seek out unparamaterized queries in ColdFusion templates and, at user's option, 
	parameterize them.

Use:

	Place _ParameterizeQueries.cfm in a document directory and load.
	Template will start from its current directory and proceed to read all .cfm documents in that 
	directory, find and report all <CFQUERY>s found, and, if it looks like there's a spot that
	<cfqueryparam> can be used, give you the option to parameterize the query.

	If "beRecursive" is set to True (just after these comments), it will recursively
	search all subdirectories, too.

	If "overwriteInPlace" is set to True (just after these comments), it will replace the files
	in place, and save a copy of the "before" file as ".old".  If false, changes will be saved in
	files with ".new" appended.

	To parameterize, click the "Parameterize!" button at the bottom, and all selected queries
	will be parameterized, and the resulting template saved.
	Be sure to test the changes before placing the new code into production!!!

	Templates beginning with an underscore character ("_") will be skipped.
	If working recursively, directories starting with a period (".") will be skipped.
	
	Do NOT leave this on production servers..!
	
Legal:

	Furnished without warranty of ANY KIND including merchantability
	or fitness for any particular purpose.  Use at your own exclusive risk.
	
--->

<cfscript>
	function getTypeStr(theParam) {
		// Put you heuristic here
		if (theParam contains "now()" or theParam contains "date") {
			return "CF_SQL_TIMESTAMP";
		}
		return "";
	}
	
	function buildNewParam(theParam) {
		return buildCfqueryparam(theParam, buildTypeAttr(theParam));
	}
	
	function buildTypeAttr(theParam) {
		var typeStr = getTypeStr(theParam);
		
		var typeAttr = "";
		if (typeStr neq "") {
			typeAttr = " cfsqltype=""#typeStr#""";
		}
		return typeAttr;
	}
	
	function buildCfqueryparam(theParam, typeAttr) {
		return "<cfqueryparam value=""#theParam#""#typeAttr#>";
	}
	
	function buildNewParamForDisplay(theParam, newParam) {
		return buildCfqueryparamForDisplay(newParam, theParam, buildTypeAttr(theParam));
	}
	
	function buildCfqueryparamForDisplay(newParam, theParam, typeAttr) {
		return newParam & "</strike><b>&lt;cfqueryparam value=""#theParam#""#typeAttr#></b>";
	}	
	
	function rewriteQuery(SQL, pattern) {
		var theParam = "";
		var newParam = "";
		var prefix = "";
		var startIdx = 1;		
		var st = reFind(pattern,SQL,startIdx,true);
		while (st.pos[1]) {
			prefix = mid(SQL, startIdx, st.pos[1] - startIdx);
			theParam = mid(SQL, st.pos[2], st.len[2]);
			if (left(theParam,1) IS "'") {
				theParam=mid(theParam,2,len(theParam)-2);
			}
			if (prefix does not contain "&lt;cf") {
				SQL=removechars(SQL,st.pos[2],st.len[2]);
				newParam = buildNewParam(theParam);
				SQL=insert(newParam,SQL,st.pos[2]-1);
				startIdx = st.pos[1]+len(newParam);
			} else {
				startIdx = st.pos[2] + st.len[2];
			}
			st = reFind(pattern, SQL, startIdx, true);
		}
		return SQL;
	}
	
	function rewriteQueryForDisplay(SQL, pattern) {
		var theParam = "";
		var newParam = "";
		var data = structNew();
		var Fixable=false;
		var prefix = "";
		var startIdx = 1;
		var st = reFind(pattern,SQL,startIdx,true);
		while (st.pos[1]) {
			prefix = mid(SQL, startIdx, st.pos[1] - startIdx);
			theParam = mid(SQL, st.pos[2], st.len[2]);
			if (left(theParam,1) IS "'") {
				theParam=mid(theParam,2,len(theParam)-2);						
			}
			if (prefix does not contain "&lt;cf") {
				Fixable=true;
				newParam = "<strike>" & theParam;
				newParam = buildNewParamForDisplay(theParam, newParam);
				SQL=removechars(SQL,st.pos[2],st.len[2]);
				SQL=insert(newParam,SQL,st.pos[2]-1);
				startIdx = st.pos[1]+len(newParam);
			} else {
				startIdx = st.pos[2] + st.len[2];
			}
			st = reFind(pattern,SQL,startIdx,true);
		}
		data.Fixable= Fixable;
		data.SQL = SQL;
		return data;
	}
	
	function getPattern(queryType) {
		var pattern = "";
		if (queryType is "insert") {
			pattern = "([']?##[^##]+##[']?)";	
		} else {
			pattern = "=[[:space:]]*([']?##[^##]+##[']?)";	
		}
		return pattern;
	}
</cfscript>

<cffunction name="dump">
	<cfargument name="var_name">
	<cfdump var="#var_name#">
</cffunction>

<!--- set to True to work on directories recursively --->
<CFSET beRecursive=true>
<!--- set to True to overwrite files (saving old ones as .old), False to create new ".new" files. --->
<CFSET overwriteInPlace=true>
<!--- default the checkbox to CHECKED --->
<CFSET isDefaultChecked=true>

<!--- don't edit below this line (unless you don't mind breaking stuff!) --->
<CFSET crlf = "
">
<CFIF isDefined("Attributes.CurDir")>
	<CFSET CurDir = Attributes.CurDir>
<CFELSE>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">

<html>
<head>
	<title>Queries</title>
</head>

<body>
<CFSET CurDir="#GetDirectoryFromPath(CGI.Path_Translated)#">
</CFIF>

<cfdirectory action="List" 
	Directory="#CurDir#"
	name="dir" 
	filter="*.cfm|*.cfc|*.cfml">

<FORM Action="_parameterizeQueries.cfm" Method="POST">
<CFPARAM Name="ffFixMe" default="">
<TABLE Border=1>
<CFOUTPUT>
<TR>
	<TH Colspan=2 bgColor="ffff99"><font face="arial">Files in #CurDir#:</font></TH>
</TR>
</CFOUTPUT>
<TR>
	<TH bgColor="eeeeee"><font face="arial">Name</font></TH>
	<TH bgColor="eeeeee"><font face="arial">Info</font></TH>
</TR>
<CFSET TotalLines=0>
<CFSET TotalSize=0>
<cfset sql = "">
<CFLOOP Query="Dir">
<CFIF left(Dir.Name,1) IS NOT "_">
	<CFFILE Action="Read" File="#CurDir#\#Dir.Name#" Variable="TheFile">
	<cfset theOriginalFile = theFile>
	<cfset rewrite=false>
	<CFOUTPUT>
	<TR>
		<TD><font face="arial">#Dir.Name#</font></TD>
		<TD><CFSET NumLines = ListLen(TheFile,crlf)>
			<font face="arial">#Dir.Size# bytes, #NumLines# Lines</font>
			<CFSET TotalSize = TotalSize + Dir.Size>
			<CFSET TotalLines = TotalLines + Numlines>
		</TD>
	</TR>
	</CFOUTPUT>
	<cftry>
	<CFSET curpos = findNoCase("<CFQUERY",TheFile)>
	<CFLOOP Condition="#curpos#">
		<CFSET endOfTagPos = findNoCase(">",TheFile,curpos)>
		<CFSET StartTag = mid(TheFile,curpos,endOfTagPos-curpos+1)>
		<CFOUTPUT><TR><TD></TD><TD></CFOUTPUT>
		<CFIF (StartTag CONTAINS "SQL=") or (right(StartTag,2) IS "/>")>
			<CFOUTPUT><pre>#htmlcodeformat(StartTag)#</pre></CFOUTPUT>
			<CFSET curpos = endOfTagPos-curpos+1>
		<CFELSEIF (startTag contains "cachedWithin")>
			<CFSET endTagPos = findNoCase("</CFQUERY>",TheFile,curPos)+10>
			<CFSET SQL = mid(TheFile, EndOfTagPos+1, endTagPos-EndOfTagPos-1)>
			<CFOUTPUT><pre><font color="red">#htmlcodeformat(StartTag & sql)#</font></pre></CFOUTPUT>
			<CFSET curpos = endOfTagPos>
		<CFELSE>
			<CFSET endTagPos = findNoCase("</CFQUERY>",TheFile,curPos)+10>
			<CFSET SQL = mid(TheFile, EndOfTagPos+1, endTagPos-EndOfTagPos-1)>
			<cfset queryType = getToken(trim(sql), 1)>
			<CFSET SQLHash = hash(SQL)>
			<CFIF listFind(ffFixMe,SQLHash)>
				<!--- actually fix the sql --->
				<cfset rewrite=true>
				<CFSET SQL=rewriteQuery(SQL, getPattern(queryType))>;
				<CFOUTPUT>
				<strong>Parameterized!</strong><br>
				<pre>#htmlcodeformat(StartTag & SQL)#</pre>
				</CFOUTPUT>
				<CFSET TheFile = removeChars(TheFile, EndOfTagPos+1, endTagPos-EndOfTagPos-1)>
				<CFSET TheFile = insert(SQL, TheFile, EndOfTagPos)>
				<CFSET Curpos = EndOfTagPos+1+len(SQL)>
			<CFELSE>
				<CFSET SQL = htmlCodeFormat(SQL)>
				<CFSET SQL = htmlCodeFormat(mid(TheFile, EndOfTagPos+1, endTagPos-EndOfTagPos-1))>
				<CFSET data = rewriteQueryForDisplay(SQL, getPattern(queryType))>
				<CFSET Fixable=data.Fixable>
				<CFSET SQL=data.SQL>
				<CFOUTPUT>
				<CFIF Fixable><INPUT Type="Checkbox" Name="ffFixMe" value="#SQLHash#" <cfif isDefaultChecked>CHECKED</cfif>>Parameterize Me:<br></CFIF>
				<pre>#htmlcodeformat(StartTag)##SQL#</pre>
				</CFOUTPUT>
				<CFSET curpos = endTagPos>
			</CFIF>
		</CFIF>
		<CFOUTPUT></TD></TR></CFOUTPUT>
		<CFSET curpos = findNoCase("<CFQUERY",TheFile,curpos)>
	</CFLOOP>
	<CFIF ReWrite>
		<cfif overwriteInPlace>
<!---			
	   		<CFFILE Action="Write" 
				File="#CurDir#\#Dir.Name#.old"
			    OUTPUT="#TheOriginalFile#"
			    ADDNEWLINE="No"
			>
--->			
	   		<CFFILE Action="Write" 
				File="#CurDir#\#Dir.Name#"
			    OUTPUT="#TheFile#"
			    ADDNEWLINE="No"
			>
			<CFOUTPUT><TR><TD></TD><TD>File "#CurDir#\#Dir.Name#" written.  Old version saved as ".old"</TD></TR></CFOUTPUT>
		<cfelse>
	   		<CFFILE Action="Write" 
				File="#CurDir#\#Dir.Name#.new"
			    OUTPUT="#TheFile#"
			    ADDNEWLINE="No"
			>
			<CFOUTPUT><TR><TD></TD><TD>File "#CurDir#\#Dir.Name#.new" written.</TD></TR></CFOUTPUT>
		</cfif>
	</CFIF>
	<cfcatch type="any">
		<cfoutput>
		<TR><TD></TD><TD>
		<strong>Error parsing query:</strong>
		<pre>#htmlcodeformat(StartTag & SQL)#</pre>
		#cfcatch.message#<br>
		#cfcatch.detail#
		</TD></TR>
		<CFSET curpos = endTagPos>
		</cfoutput>
	</cfcatch>
	</cftry>
</CFIF>
<CFFLUSH>
</CFLOOP>
<CFOUTPUT>
<TR>
	<TD bgColor="eeeeee"><font face="arial"><b>Totals:</b></font></TD>
	<TD bgColor="eeeeee" Align="Right"><font face="arial">#numberFormat(TotalSize)#</font></TD>
	<TD bgColor="eeeeee" Align="Right"><font face="arial">#numberFormat(TotalLines)#</font></TD>
</TR>
</CFOUTPUT>
</TABLE>

<CFIF beRecursive>
<CFDIRECTORY Action="List" 
	Directory="#CurDir#" 
	Name="Dir">
<CFLOOP Query="Dir">
	<CFIF Dir.Type IS "Dir" AND left(Dir.Name,1) IS NOT ".">
		<CFMODULE template="_parameterizeQueries.cfm" CurDir="#CurDir#\#Dir.Name#">
	</CFIF>
</CFLOOP>
</CFIF>

<CFIF isDefined("Attributes.CurDir")>
	<CFSET Caller.TotalSize = Caller.TotalSize + TotalSize>
	<CFSET Caller.TotalLines = Caller.TotalLines + TotalLines>
<CFELSE>
	<CFOUTPUT>
	<TABLE>
	<TR>
		<TH bgColor="eeeeee">&nbsp;</TH>
		<TH bgColor="eeeeee"><font face="arial">Size</font></TH>
		<TH bgColor="eeeeee"><font face="arial">Lines</font></TH>
	</TR>
	<TR>
		<TD bgColor="eeeeee"><font face="arial"><b>Grand Totals:</b></font></TD>
		<TD bgColor="eeeeee" Align="Right"><font face="arial">#numberFormat(TotalSize)#</font></TD>
		<TD bgColor="eeeeee" Align="Right"><font face="arial">#numberFormat(TotalLines)#</font></TD>
	</TR>
	</TABLE>
	<INPUT Type="Submit" value="Parameterize Selected">
	</FORM>
	</body>
	</html>
	</CFOUTPUT>
</CFIF>