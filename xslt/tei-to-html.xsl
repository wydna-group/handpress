<?xml version="1.0" encoding="UTF-8"?>
<!--
     tei-to-html.xsl - a plain reading text of the TEI, for anyone who wants
     to look at the file without Racket.

     This is deliberately not the facsimile, and it used to be. That was the
     mistake: two renderings of one book, each knowing things the other did
     not, drifting apart in ways the parity test between them never caught -
     a stylesheet that existed twice and went stale in one copy, a script only
     one of them loaded, classes only one of them emitted. The facsimile is
     now built by tei-html.rkt out of the .tei.xml and nothing else, and is
     authoritative.

     So what is left here is the job XSLT 1.0 is good at - walking a document
     and emitting text - and none of the jobs it is bad at. No statistics, no
     key, no deviation colouring, no leaf and sheet grouping, no damaged type,
     no computed word positions. Those are computations over counts and joins
     against declared taxonomies, and XSLT 1.0 has neither functions nor
     grouping. Doing them in XSLT 3.0 would mean adding Saxon and a JRE in
     order to duplicate Racket that already exists.

     What it keeps is the half of the book the facsimile does not show: the
     reading rather than the glyph. <reg> not <orig>, <expan> not <abbr>,
     <corr> not <sic>. That is the honest reason for this file to exist, and
     it is a claim it can keep.
-->
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:tei="http://www.tei-c.org/ns/1.0"
                xmlns:hp="https://handpress.invalid/ns/1.0"
                exclude-result-prefixes="tei hp">

  <xsl:output method="html" encoding="UTF-8" indent="no"
              doctype-system="about:legacy-compat"/>
  <xsl:strip-space elements="*"/>

  <!-- Which made-up copy to show, where the copies differ. -->
  <xsl:param name="witness" select="'copya'"/>
  <xsl:param name="layout" select="'reading'"/>

  <xsl:template match="/">
    <html lang="en">
      <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title><xsl:value-of select="//tei:titleStmt/tei:title"/></title>
        <style>
          body { max-width: 34em; margin: 3rem auto; padding: 0 1rem;
                 font: 1rem/1.7 Georgia, 'Times New Roman', serif;
                 color: #1a1a1a; background: #fbfaf7; }
          h1 { font-size: 1.4rem; font-weight: normal; letter-spacing: .08em; }
          .note { color: #6b6459; font-size: .82rem; line-height: 1.55;
                  border-left: 2px solid #d8d0c0; padding-left: .9rem;
                  margin-bottom: 2.5rem; }
          .pb { display: block; margin: 1.7rem 0 .4rem; color: #8a8275;
                font-size: .72rem; letter-spacing: .14em;
                text-transform: uppercase; }
          .fw { color: #8a8275; font-size: .82rem; font-style: italic;
                margin: 0 0 .5rem; }
          p { margin: 0 0 .25rem; }
          .it { font-style: italic; }
          @media (prefers-color-scheme: dark) {
            body { background: #16150f; color: #e6e1d4; }
            .note, .pb, .fw { color: #9a927f; }
          }
        </style>
      </head>
      <body>
        <h1><xsl:value-of select="//tei:titleStmt/tei:title"/></h1>
        <p class="note">
          A plain reading text, generated from the TEI by
          tei-to-html.xsl. It gives the words and the page breaks, in the
          reading rather than in the glyphs the compositor set. For the
          type-facsimile - every word at the position computed for it, with
          the damaged sorts, the departures from copy and the statistics - see
          the HTML that handpress writes beside this file.
        </p>
        <xsl:apply-templates select="//tei:body"/>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="tei:div[@type='page']">
    <span class="pb">
      <xsl:value-of select="@n"/>
      <xsl:if test="tei:fw[@type='pageNum']">
        <xsl:text> &#183; </xsl:text>
        <xsl:value-of select="tei:fw[@type='pageNum']"/>
      </xsl:if>
    </span>
    <xsl:if test="tei:fw[@type='head']">
      <p class="fw"><xsl:value-of select="tei:fw[@type='head']"/></p>
    </xsl:if>
    <xsl:apply-templates select=".//tei:ab"/>
  </xsl:template>

  <!-- Words are siblings of the <lb/> milestones, not children of them. A
       reading text does not want the type lines at all: it wants the words
       with single spaces between them, and lets the reader's window break
       them where it likes. Which is why the grouping problem that made this
       stylesheet difficult simply disappears once it stops trying to be a
       facsimile. -->
  <xsl:template match="tei:ab">
    <p><xsl:apply-templates select="tei:w"/></p>
  </xsl:template>

  <xsl:template match="tei:w">
    <xsl:choose>
      <xsl:when test="@rend='italic'">
        <span class="it"><xsl:apply-templates/></span>
      </xsl:when>
      <xsl:otherwise><xsl:apply-templates/></xsl:otherwise>
    </xsl:choose>
    <xsl:text> </xsl:text>
  </xsl:template>

  <!-- The reading, never the glyph. This is the whole difference between this
       file and the facsimile. -->
  <xsl:template match="tei:choice">
    <xsl:choose>
      <xsl:when test="tei:reg"><xsl:value-of select="tei:reg"/></xsl:when>
      <xsl:when test="tei:expan"><xsl:value-of select="tei:expan"/></xsl:when>
      <xsl:when test="tei:corr"><xsl:value-of select="tei:corr"/></xsl:when>
      <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- A press variant: the chosen witness's reading. -->
  <xsl:template match="tei:app">
    <xsl:choose>
      <xsl:when test="tei:rdg[contains(@wit, concat('#', $witness))]">
        <xsl:value-of select="tei:rdg[contains(@wit, concat('#', $witness))][1]"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="tei:rdg[1]"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Structure, not text. There is deliberately no catch-all suppressing
       text(): an earlier draft had one, and it swallowed the words inside <w>
       along with everything else, leaving a document of empty spans. Nothing
       stray leaks in without it, because the templates above only ever apply
       to elements they name. -->
  <xsl:template match="tei:lb|tei:pb|tei:cb|tei:fw"/>

</xsl:stylesheet>
