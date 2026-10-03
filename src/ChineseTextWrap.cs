using System;
using System.Text;
using UnityEngine;
public static class ChineseTextWrap {
 public static string Wrap(string text, TextMesh mesh, float width, out int lines) {
  lines=0;
  if (String.IsNullOrEmpty(text)) return String.Empty;
  if (width<=0) {lines=1;return text;}
  Renderer renderer=mesh.GetComponent<Renderer>();
  if(renderer==null) {lines=1;return text;}
  StringBuilder result=new StringBuilder();
  string line=String.Empty;
  lines=1;
  for(int i=0;i<text.Length;i++) {
   char c=text[i];
   if(c=='\r')continue;
   if(c=='\n') {result.Append(line.TrimEnd());result.Append('\n');line=String.Empty;lines++;continue;}
   string token=c.ToString();
   // Keep Latin words, addresses, and numbers together within Chinese prose.
   if((c>='a'&&c<='z')||(c>='A'&&c<='Z')||(c>='0'&&c<='9')) {
    int end=i+1;
    while(end<text.Length) {
     char next=text[end];
     if(!((next>='a'&&next<='z')||(next>='A'&&next<='Z')||(next>='0'&&next<='9')||next=='_'||next=='-'||next=='.'||next=='@'))break;
     end++;
    }
    token=text.Substring(i,end-i);i=end-1;
   }
   mesh.text=line+token;
   bool closing="，。！？；：、）】》”’…".IndexOf(c)>=0;
   if(line.Length>0&&renderer.bounds.size.x>width&&!closing) {
    // Opening quotes and brackets travel with the text they introduce.
    string carry=String.Empty;
    if("（【《“‘".IndexOf(line[line.Length-1])>=0) {
     carry=line.Substring(line.Length-1);line=line.Substring(0,line.Length-1);
    }
    result.Append(line.TrimEnd());result.Append('\n');lines++;
    line=carry+token.TrimStart();
   } else line+=token;
  }
  result.Append(line.TrimEnd());
  string wrapped=result.ToString();mesh.text=wrapped;return wrapped;
 }
}
