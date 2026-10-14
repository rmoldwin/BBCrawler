/* ===========================================================================
   00_dbo_Clean.sql

   The corrected dbo.Clean scalar UDF (regenerated 2026-07-09), included here so
   the SQL Server folder is self-contained. This is the AUTHORITATIVE source of
   truth for the normalization logic; python/clean_term.py mirrors it 1:1.

   Deploy this first, then 01_deploy_clean.sql (indexed key column), then use
   the recipes in 02_search_examples.sql.

   NOTE: paste of the maintainer's deployed function body. If you edit it,
   re-mirror the change in python/clean_term.py and re-run tests/test_parity.py.
   =========================================================================== */
CREATE OR ALTER FUNCTION [dbo].[Clean]
(
    @StringIn NVARCHAR(MAX)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    IF @StringIn IS NULL RETURN NULL;
    IF TRIM(@StringIn) = '' RETURN '';

    DECLARE @StringOut NVARCHAR(MAX) = @StringIn;

    SELECT @StringOut = REPLACE(@StringOut, NCHAR(160), ' ');
    SELECT @StringOut = REPLACE(@StringOut, '/', ' ');

    SELECT @StringOut = REPLACE(@StringOut, NCHAR(0x200B), '');   -- zero-width space
    SELECT @StringOut = REPLACE(@StringOut, NCHAR(0x00AD), '');   -- soft hyphen
    SELECT @StringOut = REPLACE(@StringOut, NCHAR(0xFEFF), '');   -- zero-width no-break space

    SELECT @StringOut = REPLACE(@StringOut, ',', '');
    SELECT @StringOut = TRIM(LEADING '+' FROM @StringOut);
    SELECT @StringOut = TRIM(LEADING '?' FROM @StringOut);
    SELECT @StringOut = REPLACE(@StringOut, '#', '');

    -- FIX 1: dashes -> space BEFORE the NOS/type removals
    SELECT @StringOut = REPLACE(@StringOut, '-', ' ');
    SELECT @StringOut = REPLACE(@StringOut, NCHAR(0x2013), ' ');  -- en dash
    SELECT @StringOut = REPLACE(@StringOut, NCHAR(0x2014), ' ');  -- em dash

    WHILE CHARINDEX('  ', @StringOut) > 0
        SELECT @StringOut = REPLACE(@StringOut, '  ', ' ');

    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_100_BIN2, ' NOS', '');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_100_BIN2, ' (NOS)', '');

    -- grade <roman> -> grade <digit>
    IF @StringOut COLLATE Latin1_General_100_BIN2 LIKE '% grade III' SELECT @StringOut = LEFT(@StringOut, LEN(@StringOut)-3) + '3';
    ELSE IF @StringOut COLLATE Latin1_General_100_BIN2 LIKE '% grade II' SELECT @StringOut = LEFT(@StringOut, LEN(@StringOut)-2) + '2';
    ELSE IF @StringOut COLLATE Latin1_General_100_BIN2 LIKE '% grade I'  SELECT @StringOut = LEFT(@StringOut, LEN(@StringOut)-1) + '1';

    -- FIX 2: type <roman> -> <digit> (drop word 'type')
    IF @StringOut COLLATE Latin1_General_100_BIN2 LIKE '% type III' SELECT @StringOut = LEFT(@StringOut, LEN(@StringOut)-8) + '3';
    ELSE IF @StringOut COLLATE Latin1_General_100_BIN2 LIKE '% type II' SELECT @StringOut = LEFT(@StringOut, LEN(@StringOut)-7) + '2';
    ELSE IF @StringOut COLLATE Latin1_General_100_BIN2 LIKE '% type I'  SELECT @StringOut = LEFT(@StringOut, LEN(@StringOut)-6) + '1';

    -- FIX 3: ACRONYM <roman> -> ACRONYM <digit>
    IF @StringOut COLLATE Latin1_General_100_BIN2 LIKE '%[A-Z][A-Z] III'
        SELECT @StringOut = LEFT(@StringOut, LEN(@StringOut)-3) + '3';
    ELSE IF @StringOut COLLATE Latin1_General_100_BIN2 LIKE '%[A-Z][A-Z] II'
        SELECT @StringOut = LEFT(@StringOut, LEN(@StringOut)-2) + '2';
    ELSE IF @StringOut COLLATE Latin1_General_100_BIN2 LIKE '%[A-Z][A-Z] I'
        SELECT @StringOut = LEFT(@StringOut, LEN(@StringOut)-1) + '1';

    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_100_BIN2, ' type', '');

    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'non ', 'non');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Non ', 'Non');

    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Naev', 'Nev');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'naev', 'nev');

    -- FIX 4: British -> American, case-preserving
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Tumour', 'Tumor');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'tumour', 'tumor');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Colour', 'Color');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'colour', 'color');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Grey', 'Gray');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'grey', 'gray');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Mould', 'Mold');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'mould', 'mold');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_100_BIN2, 'of the ', 'of ');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'aem', 'em');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Aem', 'Em');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'paed', 'ped');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Paed', 'Ped');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'paen', 'pen');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Paen', 'Pen');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'phaeo', 'pheo');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Phaeo', 'Pheo');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'melaen', 'melen');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Melaen', 'Melen');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Goitre', 'Goiter');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'goitre', 'goiter');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Centre', 'Center');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'centre', 'center');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Oedema', 'Edema');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'oedema', 'edema');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Oesophag', 'Esophag');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'oesophag', 'esophag');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Coeli', 'Celi');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'coeli', 'celi');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'rhoea', 'rhea');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Oestr', 'Estr');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'oestr', 'estr');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Foet', 'Fet');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'foet', 'fet');

    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_100_BIN2, '''s', '');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_100_BIN2, NCHAR(0x2019) + 's', '');

    SELECT @StringOut = SUBSTRING(@StringOut, 1, (CHARINDEX('(specify', @StringOut COLLATE Latin1_General_100_BIN2, 1) - 1))
        WHERE CHARINDEX('(specify', @StringOut COLLATE Latin1_General_100_BIN2, 1) > 0;

    WHILE CHARINDEX('  ', @StringOut) > 0
        SELECT @StringOut = REPLACE(@StringOut, '  ', ' ');
    SELECT @StringOut = TRIM(@StringOut);

    RETURN @StringOut;
END
GO
