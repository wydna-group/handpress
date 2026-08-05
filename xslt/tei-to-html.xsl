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
        <link rel="stylesheet" href="facsimile.css"/>
        <script src="facsimile.js" defer="defer"></script>
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
      <!-- The units a page belongs to. The signature carries them: A3r is
           leaf 3 of gathering A, and its recto. Sheet membership needs the
           format, which the header records as leaves per gathering; for a
           gathering folded from one sheet every leaf is that sheet, and for a
           quired one leaf L pairs with leaf (leaves+1-L). -->
      <xsl:attribute name="data-leaf">
        <xsl:value-of select="@hp:leaf"/>
      </xsl:attribute>
      <xsl:attribute name="data-sheet">
        <xsl:value-of select="@hp:sheet"/>
      </xsl:attribute>
      <xsl:attribute name="data-forme">
        <xsl:value-of select="@hp:forme"/>
      </xsl:attribute>
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

      <div class="unit">
        <span data-unit="leaf">leaf <xsl:value-of select="@hp:leaf"/></span>
        <span data-unit="sheet">sheet <xsl:value-of select="@hp:sheet"/></span>
        <span data-unit="forme">forme</span>
      </div>

      <!-- The headline: page number and running title stood in it together,
           both of them forme work carried from forme to forme with the
           skeleton. The number goes to the outer edge, left on a verso and
           right on a recto, which is where its type was. -->
      <div class="headline">
        <span class="fol left">
          <xsl:apply-templates select="tei:fw[@type='pageNum'][@place='top-left']"/>
        </span>
        <span class="runhead">
          <xsl:attribute name="title">
            <xsl:value-of select="tei:fw[@type='head']/@hp:damage"/>
          </xsl:attribute>
          <xsl:value-of select="tei:fw[@type='head']"/>
        </span>
        <span class="fol right">
          <xsl:apply-templates select="tei:fw[@type='pageNum'][@place='top-right']"/>
        </span>
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
        <!-- The stage that moved this word away from its copy, from the
             taxonomy declared in the header. Faint on the page by design:
             it should read as a page first. -->
        <xsl:if test="@ana='#misreading'"> dev-misread</xsl:if>
        <xsl:if test="@ana='#division'"> dev-divided</xsl:if>
        <xsl:if test="@ana='#foul-case'"> dev-accident</xsl:if>
        <xsl:if test="@ana='#justification'"> dev-fit</xsl:if>
        <xsl:if test="@ana='#habit'"> dev-habit</xsl:if>
      </xsl:attribute>
      <xsl:attribute name="style">
        <xsl:text>--x:</xsl:text><xsl:value-of select="@hp:x"/>
        <xsl:text>;--w:</xsl:text><xsl:value-of select="@hp:w"/>
      </xsl:attribute>
      <xsl:attribute name="title"><xsl:call-template name="gloss"/></xsl:attribute>
      <!-- The text carries the reading; hp:glyph carries the form as set.
           A facsimile shows the type, so where they differ the glyphs win.
           Anything reading the text instead gets searchable English. -->
      <xsl:choose>
        <xsl:when test="@hp:glyph and not(tei:choice) and not(tei:app)">
          <xsl:value-of select="@hp:glyph"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="node()"/>
        </xsl:otherwise>
      </xsl:choose>
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
      <xsl:when test="@ana='#misreading'">misreading: the copy read otherwise</xsl:when>
      <xsl:when test="@ana='#division'">division: half a word broken at the line end — the reading is whole</xsl:when>
      <xsl:when test="@ana='#justification'">justification: altered so the line would fill the measure</xsl:when>
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
  <!-- A page number the compositor got wrong is still the number that
       printed, so it stands as it is; @n carries what it should have been. -->
  <xsl:template match="tei:fw[@type='pageNum']">
    <span>
      <xsl:attribute name="class">
        <xsl:text>pageno</xsl:text>
        <xsl:if test="@n"> wrong</xsl:if>
      </xsl:attribute>
      <xsl:if test="@n">
        <xsl:attribute name="title">
          <xsl:value-of select="@hp:error"/>
          <xsl:text> — should be </xsl:text>
          <xsl:value-of select="@n"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:value-of select="."/>
    </span>
  </xsl:template>

  <xsl:template match="tei:fw"/>

  <!-- ================================================================== -->

  <!-- The stylesheet is not here. It lives in xslt/facsimile.css, which
       render.rkt reads for the direct HTML and this links for the TEI one.
       It used to exist in both places and the two drifted, until the TEI
       rendering had none of the page numbers, deviation marks or unit
       grouping the direct one had grown. main.rkt copies the file beside the
       output. -->


</xsl:stylesheet>
