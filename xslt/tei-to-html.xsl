<?xml version="1.0" encoding="UTF-8"?>
<!--
     tei-to-html.xsl - a type-facsimile from TEI.

     XSLT 1.0, because the only processor guaranteed to be present on this
     machine is .NET's XslCompiledTransform. That rules out xsl:function,
     for-each-group and regular expressions, and it makes the grouping
     problem the interesting part.

     Type lines are milestones in the source, so the words of a line are not
     children of anything. They are siblings that happen to follow one lb
     and precede the next. XSLT 1.0 groups them the old way: for each lb,
     select the following w whose nearest preceding lb is this one, compared
     by generate-id().

     Every word carries the em offset the simulated compositor computed for
     it, so the justification you see is his and not the browser's.
-->
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:tei="http://www.tei-c.org/ns/1.0"
                xmlns:hp="https://handpress.invalid/ns/1.0"
                exclude-result-prefixes="tei hp">

  <xsl:output method="html" encoding="UTF-8" indent="no"
              doctype-system="about:legacy-compat"/>

  <xsl:strip-space elements="*"/>

  <!-- Which made-up copy to show, where the copies differ. Pass e.g.
       -stringparam witness copyb to see another state of the edition. -->
  <xsl:param name="witness" select="'copya'"/>

  <!-- How the leaves are laid out.

       'opening' shows the book as a reader holds it: the verso of one leaf
       on the left and the recto of the next on the right. The first recto
       therefore stands alone on the right of the first opening, and a final
       verso alone on the left, exactly as in a bound copy.

       'leaf' shows the two sides of a single leaf side by side, recto then
       verso. That is not a view anyone ever has of a book, but it is the
       view the compositor and the pressman had of a page of type, and it
       puts the two formes of a leaf where they can be compared. -->
  <xsl:param name="layout" select="'opening'"/>

  <!-- =================================================================== -->

  <xsl:template match="/">
    <html lang="en">
      <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title><xsl:value-of select="//tei:titleStmt/tei:title"/></title>
        <style><xsl:call-template name="css"/></style>
      </head>
      <body>
        <div class="wrap">
          <h1><xsl:value-of select="//tei:titleStmt/tei:title"/></h1>
          <p class="lede">
            <xsl:value-of select="//tei:sourceDesc/tei:bibl/tei:extent"/>
            <xsl:text> · </xsl:text>
            <xsl:value-of select="//tei:sourceDesc/tei:bibl/tei:note[@type='measure']"/>
            <xsl:text> · rendered from TEI by XSLT. Showing </xsl:text>
            <xsl:choose>
              <xsl:when test="//tei:witness[@xml:id=$witness]">
                <xsl:value-of select="//tei:witness[@xml:id=$witness]"/>
              </xsl:when>
              <xsl:otherwise>the type as set</xsl:otherwise>
            </xsl:choose>
            <xsl:text>.</xsl:text>
          </p>
          <xsl:call-template name="description"/>
          <xsl:choose>
            <xsl:when test="$layout='leaf'">
              <!-- pair (recto, verso): pages 1&2, 3&4, ... -->
              <xsl:for-each select="//tei:body/tei:div[@type='page']">
                <xsl:if test="position() mod 2 = 1">
                  <xsl:call-template name="spread">
                    <xsl:with-param name="left" select="."/>
                    <xsl:with-param name="right"
                                    select="following-sibling::tei:div[@type='page'][1]"/>
                  </xsl:call-template>
                </xsl:if>
              </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
              <!-- openings: (—,1) then (2,3), (4,5) ... -->
              <xsl:for-each select="//tei:body/tei:div[@type='page']">
                <xsl:choose>
                  <xsl:when test="position() = 1">
                    <xsl:call-template name="spread">
                      <xsl:with-param name="right" select="."/>
                    </xsl:call-template>
                  </xsl:when>
                  <xsl:when test="position() mod 2 = 0">
                    <xsl:call-template name="spread">
                      <xsl:with-param name="left" select="."/>
                      <xsl:with-param name="right"
                                      select="following-sibling::tei:div[@type='page'][1]"/>
                    </xsl:call-template>
                  </xsl:when>
                </xsl:choose>
              </xsl:for-each>
            </xsl:otherwise>
          </xsl:choose>
          <xsl:call-template name="apparatus"/>
        </div>
      </body>
    </html>
  </xsl:template>

  <!-- ================================================================== -->
  <!-- An opening, or a leaf: two pages side by side                       -->

  <xsl:template name="spread">
    <xsl:param name="left" select="/.."/>
    <xsl:param name="right" select="/.."/>
    <div class="spread">
      <!-- A leaf is a fixed piece of paper whatever quantity of type stands
           on it, so every leaf in the book gets the depth of a full page. -->
      <xsl:attribute name="style">
        <xsl:text>--lines:</xsl:text>
        <xsl:value-of select="//tei:layout/@writtenLines"/>
      </xsl:attribute>
      <div class="side">
        <xsl:choose>
          <xsl:when test="$left">
            <xsl:apply-templates select="$left"/>
            <xsl:call-template name="folio">
              <xsl:with-param name="p" select="$left"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <div class="leaf absent"></div>
            <div class="folio empty">outside the book</div>
          </xsl:otherwise>
        </xsl:choose>
      </div>
      <div class="side">
        <xsl:choose>
          <xsl:when test="$right">
            <xsl:apply-templates select="$right"/>
            <xsl:call-template name="folio">
              <xsl:with-param name="p" select="$right"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <div class="leaf absent"></div>
            <div class="folio empty">outside the book</div>
          </xsl:otherwise>
        </xsl:choose>
      </div>
    </div>
  </xsl:template>

  <!-- Which leaf this is, and which side of it -->
  <xsl:template name="folio">
    <xsl:param name="p"/>
    <xsl:variable name="n" select="$p/@n"/>
    <xsl:variable name="side" select="substring($n, string-length($n))"/>
    <xsl:variable name="leaf" select="substring($n, 1, string-length($n) - 1)"/>
    <div class="folio">
      <span class="sig"><xsl:value-of select="$n"/></span>
      <xsl:text> — leaf </xsl:text>
      <xsl:value-of select="$leaf"/>
      <xsl:text>, </xsl:text>
      <span>
        <xsl:attribute name="class">
          <xsl:choose>
            <xsl:when test="$side='r'">rv recto</xsl:when>
            <xsl:otherwise>rv verso</xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
        <xsl:choose>
          <xsl:when test="$side='r'">recto</xsl:when>
          <xsl:otherwise>verso</xsl:otherwise>
        </xsl:choose>
      </span>
    </div>
  </xsl:template>

  <!-- ================================================================== -->
  <!-- The Bowers description, out of the TEI header                       -->

  <xsl:template name="description">
    <div class="desc">
      <h2>Bibliographical description</h2>
      <dl>
        <dt>Coll</dt>
        <dd><xsl:value-of select="//tei:supportDesc/tei:collation"/></dd>
        <dt>Extent</dt>
        <dd><xsl:value-of select="//tei:supportDesc/tei:extent"/></dd>
        <dt>Foliation</dt>
        <dd><xsl:value-of select="//tei:supportDesc/tei:foliation"/></dd>
        <dt>Type</dt>
        <dd><xsl:value-of select="//tei:typeDesc/tei:typeNote"/></dd>
        <xsl:for-each select="//tei:additions/tei:p">
          <dt><xsl:value-of select="tei:label"/></dt>
          <dd><xsl:value-of select="substring-after(., ':')"/></dd>
        </xsl:for-each>
        <dt>States</dt>
        <dd>
          <xsl:choose>
            <xsl:when test="//tei:app">
              <xsl:value-of select="count(//tei:app)"/>
              <xsl:text> press variant(s) over </xsl:text>
              <xsl:value-of select="count(//tei:witness)"/>
              <xsl:text> copies collated; see the apparatus below.</xsl:text>
            </xsl:when>
            <xsl:otherwise>No forme differs between the copies collated.</xsl:otherwise>
          </xsl:choose>
        </dd>
      </dl>
      <p class="deskey">After the form of Bowers, <i>Principles of
      Bibliographical Description</i>, i. 128-9.</p>
    </div>
  </xsl:template>

  <!-- ================================================================== -->
  <!-- A page                                                              -->

  <xsl:template match="tei:div[@type='page']">
    <div class="leaf plate">
      <div>
        <xsl:attribute name="class">
          <xsl:text>tag</xsl:text>
          <xsl:if test="@hp:pressure &gt; 0.35"> crowd</xsl:if>
          <xsl:if test="@hp:pressure &lt; -0.35"> gape</xsl:if>
        </xsl:attribute>
        <xsl:text>sig. </xsl:text><xsl:value-of select="@n"/>
        <xsl:text> · </xsl:text><xsl:value-of select="@hp:forme"/>
        <xsl:text> · Compositor </xsl:text>
        <xsl:value-of select="substring-after(@resp,'#comp')"/>
        <xsl:if test="@hp:pressure &gt; 0.35"> · crowded</xsl:if>
        <xsl:if test="@hp:pressure &lt; -0.35"> · spun out</xsl:if>
      </div>

      <div class="runhead">
        <xsl:attribute name="title">
          <xsl:value-of select="tei:fw[@type='head']/@hp:damage"/>
        </xsl:attribute>
        <xsl:value-of select="tei:fw[@type='head']"/>
      </div>
      <div class="rule"></div>

      <div class="cols">
        <xsl:apply-templates select="tei:div[@type='column']"/>
      </div>

      <div class="direction">
        <span><xsl:value-of select="tei:fw[@type='sig']"/></span>
        <span><xsl:value-of select="tei:fw[@type='catch']"/></span>
      </div>
    </div>
  </xsl:template>

  <xsl:template match="tei:div[@type='column']">
    <div class="col">
      <xsl:attribute name="style">
        <xsl:text>--m:</xsl:text><xsl:value-of select="@hp:measure"/>
      </xsl:attribute>
      <xsl:apply-templates select="tei:ab/tei:lb"/>
    </div>
  </xsl:template>

  <!-- ================================================================== -->
  <!-- A type line. The words are the following siblings whose nearest      -->
  <!-- preceding <lb/> is this one.                                        -->

  <xsl:template match="tei:lb">
    <div class="tline">
      <xsl:if test="@break='no'">
        <xsl:attribute name="title">a word is divided at the end of this line</xsl:attribute>
      </xsl:if>
      <xsl:apply-templates
        select="following-sibling::tei:w[
                  generate-id(preceding-sibling::tei:lb[1]) = generate-id(current())]"/>
    </div>
  </xsl:template>

  <!-- ================================================================== -->
  <!-- A word, placed where the compositor put it                          -->

  <xsl:template match="tei:w">
    <span>
      <xsl:attribute name="class">
        <xsl:text>w</xsl:text>
        <xsl:if test="@rend='italic'"> it</xsl:if>
        <xsl:if test="tei:choice/tei:sic"> sic</xsl:if>
        <xsl:if test="tei:choice/tei:abbr"> abbr</xsl:if>
        <xsl:if test="tei:app"> app</xsl:if>
      </xsl:attribute>
      <xsl:attribute name="style">
        <xsl:text>--x:</xsl:text><xsl:value-of select="@hp:x"/>
        <xsl:text>;--w:</xsl:text><xsl:value-of select="@hp:w"/>
      </xsl:attribute>
      <xsl:attribute name="title"><xsl:call-template name="gloss"/></xsl:attribute>
      <xsl:apply-templates select="node()"/>
    </span>
  </xsl:template>

  <!-- What the page actually shows -->
  <xsl:template match="tei:choice">
    <xsl:choose>
      <xsl:when test="tei:sic"><xsl:value-of select="tei:sic"/></xsl:when>
      <xsl:when test="tei:abbr"><xsl:value-of select="tei:abbr"/></xsl:when>
      <xsl:when test="tei:orig"><xsl:value-of select="tei:orig"/></xsl:when>
      <xsl:otherwise><xsl:apply-templates/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Where the copies differ, show the one this witness has -->
  <xsl:template match="tei:app">
    <xsl:choose>
      <xsl:when test="tei:rdg[contains(concat(@wit,' '), concat('#',$witness,' '))]">
        <xsl:value-of
          select="tei:rdg[contains(concat(@wit,' '), concat('#',$witness,' '))][1]"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="tei:rdg[1]"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Hover text: why this word looks the way it does -->
  <xsl:template name="gloss">
    <xsl:choose>
      <xsl:when test="tei:app">
        <xsl:text>press variant: </xsl:text>
        <xsl:for-each select="tei:app/tei:rdg">
          <xsl:if test="position() &gt; 1"> ] </xsl:if>
          <xsl:value-of select="."/>
          <xsl:text> (</xsl:text><xsl:value-of select="@wit"/><xsl:text>)</xsl:text>
        </xsl:for-each>
      </xsl:when>
      <xsl:when test="tei:choice/tei:sic">
        <xsl:text>foul case: </xsl:text>
        <xsl:value-of select="tei:choice/tei:sic"/>
        <xsl:text> for </xsl:text>
        <xsl:value-of select="tei:choice/tei:corr"/>
      </xsl:when>
      <xsl:when test="tei:choice/tei:abbr">
        <xsl:text>abbreviated to save room: </xsl:text>
        <xsl:value-of select="tei:choice/tei:abbr"/>
        <xsl:text> for </xsl:text>
        <xsl:value-of select="tei:choice/tei:expan"/>
      </xsl:when>
      <xsl:when test="tei:choice/tei:orig">
        <xsl:text>a fuller spelling, set to fill the line: </xsl:text>
        <xsl:value-of select="tei:choice/tei:orig"/>
        <xsl:text> for </xsl:text>
        <xsl:value-of select="tei:choice/tei:reg"/>
      </xsl:when>
      <xsl:when test="@ana='#habit'">the compositor's own spelling</xsl:when>
      <xsl:when test="@ana='#misreading'">misread from the copy</xsl:when>
      <xsl:otherwise/>
    </xsl:choose>
  </xsl:template>

  <!-- ================================================================== -->
  <!-- The apparatus, straight out of <app>                                -->

  <xsl:template name="apparatus">
    <xsl:if test="//tei:app">
      <h2>Press variants</h2>
      <div class="scroll">
        <table>
          <tr><th>page</th><th>line</th><th>readings</th></tr>
          <xsl:for-each select="//tei:app">
            <tr>
              <td class="mono">
                <xsl:value-of select="ancestor::tei:div[@type='page']/@n"/>
              </td>
              <td class="mono">
                <xsl:value-of
                  select="ancestor::tei:w/preceding-sibling::tei:lb[1]/@n"/>
              </td>
              <td>
                <xsl:for-each select="tei:rdg">
                  <xsl:if test="position() &gt; 1"> <span class="lem"> ] </span> </xsl:if>
                  <xsl:value-of select="."/>
                  <span class="wit"><xsl:value-of select="@wit"/></span>
                </xsl:for-each>
              </td>
            </tr>
          </xsl:for-each>
        </table>
      </div>
    </xsl:if>
    <h2>Responsibility</h2>
    <div class="scroll">
      <table>
        <tr><th>compositor</th><th>pages</th></tr>
        <xsl:for-each select="//tei:respStmt">
          <xsl:variable name="id" select="concat('#',@xml:id)"/>
          <tr>
            <td><xsl:value-of select="tei:name"/></td>
            <td class="mono">
              <xsl:for-each select="//tei:div[@type='page'][@resp=$id]">
                <xsl:if test="position() &gt; 1"><xsl:text>, </xsl:text></xsl:if>
                <xsl:value-of select="@n"/>
              </xsl:for-each>
            </td>
          </tr>
        </xsl:for-each>
      </table>
    </div>
  </xsl:template>

  <!-- Anything not otherwise matched contributes its text -->
  <xsl:template match="tei:fw"/>

  <!-- ================================================================== -->

  <xsl:template name="css">
:root { color-scheme: light dark; }
* { box-sizing: border-box; }
body { margin:0; padding:2.5rem 1.25rem 5rem; background:#d9d2c3;
  font-family:"Times New Roman",Times,"Liberation Serif","Nimbus Roman",ui-serif,Georgia,serif;
  color:#1a150e;
  /* declared here, not on .plate, so that a blank leaf can see them too */
  --grid:16px; --fit:1.00; --lines:38; }
@media (prefers-color-scheme: dark){ body{ background:#17140f; color:#e8e0d0; } }
.wrap { max-width:62rem; margin:0 auto; }
h1 { font-size:1.3rem; font-weight:600; letter-spacing:.09em;
     text-transform:uppercase; margin:0 0 .35rem; }
.lede { font-size:.95rem; opacity:.78; margin:0 0 2.5rem; max-width:44rem;
        line-height:1.55; }
.leaf { position:relative; margin:0 auto 3rem; padding:3.2em 3.4em 2.6em;
  background:#efe8d7; border-radius:1px;
  box-shadow:0 1px 2px rgba(0,0,0,.28),0 14px 34px rgba(0,0,0,.22);
  background-image:
    repeating-linear-gradient(90deg,rgba(120,105,80,.045) 0 1px,transparent 1px 9px),
    repeating-linear-gradient(0deg,rgba(120,105,80,.05) 0 1px,transparent 1px 34px); }
.leaf, .leaf * { color:#241c12; }
/* --grid is one em of the type body in pixels; --fit is the set width of the
   face against that body. Positions come from the simulation and only the
   glyphs come from the font, so the two must be kept apart: expressing left
   in em would scale both together and no adjustment could ever help. */
.plate { font-size:var(--grid); }
.runhead { text-align:center; letter-spacing:.22em; font-size:.82em;
           text-transform:uppercase; margin-bottom:.5em; }
.rule { border-bottom:1px solid rgba(40,28,14,.5); margin-bottom:1.1em; }
.cols { display:flex; gap:2.2em; align-items:flex-start; }
.col { position:relative; width:calc(var(--grid) * var(--m)); }
.tline { position:relative; height:calc(var(--grid) * 1.44); white-space:nowrap; }
.w { position:absolute; top:0; white-space:pre;
     left:calc(var(--grid) * var(--x));
     font-size:calc(var(--grid) * var(--fit)); }
.it { font-style:italic; }
.sic { border-bottom:1px dotted rgba(140,47,22,.55); }
.abbr { border-bottom:1px dotted rgba(29,85,96,.5); }
.app { background:rgba(190,150,60,.22); }
.direction { display:flex; justify-content:space-between; margin-top:1.4em;
             font-size:.9em; letter-spacing:.04em; }
.tag { position:absolute; top:-1.55rem; left:0; font-size:.68rem;
       letter-spacing:.11em; text-transform:uppercase; opacity:.72;
       font-family:ui-monospace,Menlo,monospace; }
.crowd { color:#8c2f16; } .gape { color:#1d5560; }
table { border-collapse:collapse; width:100%; font-size:.86rem; margin:0 0 2rem; }
th,td { text-align:left; padding:.4rem .6rem; vertical-align:top;
        border-bottom:1px solid rgba(128,110,80,.35); }
th { font-size:.72rem; letter-spacing:.1em; text-transform:uppercase;
     opacity:.7; font-weight:600; }
h2 { font-size:.78rem; letter-spacing:.13em; text-transform:uppercase;
     opacity:.72; margin:2.6rem 0 .8rem; font-weight:600; }
.mono { font-family:ui-monospace,Menlo,monospace; font-size:.86em; }
.wit { font-size:.72em; opacity:.6; margin-left:.35em; }
.lem { opacity:.5; }
.scroll { overflow-x:auto; }

/* An opening: the verso of one leaf on the left, the recto of the next on
   the right, as the book is held. The leaf is the unit of paper; the page is
   one side of it, and the two sides of a leaf are never seen together. */
.spread { display:flex; gap:1.6rem; justify-content:center; align-items:flex-start;
          margin:0 auto 3.2rem; flex-wrap:wrap; }
.spread .side { display:flex; flex-direction:column; }
/* the lines of type, plus the running head, the rule and the direction line,
   plus the margins -- about 11 ems of furniture above and below the text */
.spread .leaf { margin:0;
                min-height:calc(var(--grid) * (1.44 * var(--lines) + 11)); }
.leaf.absent { background:none; box-shadow:none;
               border:1px dashed rgba(120,105,80,.35);
               min-width:calc(var(--grid) * 26); }
.folio { text-align:center; margin-top:.55rem; font-size:.72rem;
         letter-spacing:.1em; text-transform:uppercase; opacity:.75;
         font-family:ui-monospace,Menlo,monospace; }
.folio .sig { font-weight:600; opacity:.95; }
.folio .rv.recto { color:#1d5560; }
.folio .rv.verso { color:#7a5a1e; }
.folio.empty { opacity:.4; font-style:italic; text-transform:none;
               letter-spacing:0; }

.desc { margin:0 0 3rem; padding:1.4rem 1.6rem;
        border:1px solid rgba(120,105,80,.45); border-radius:2px;
        background:rgba(255,252,244,.35); }
.desc h2 { margin-top:0; }
.desc dl { display:grid; grid-template-columns:max-content 1fr;
           gap:.35rem 1.1rem; margin:0; font-size:.86rem; line-height:1.5; }
.desc dt { font-weight:600; font-size:.72rem; letter-spacing:.08em;
           text-transform:uppercase; opacity:.65; padding-top:.15rem; }
.desc dd { margin:0; }
.deskey { font-size:.74rem; opacity:.6; margin:.9rem 0 0; }
  </xsl:template>

</xsl:stylesheet>
