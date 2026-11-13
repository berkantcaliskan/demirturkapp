YªçŠx-®éÜj×¢ëiºÚ+Š§j[h‘éÜ¢éí×yí:-jZ.¶›­–)Ş³V–×÷'Bw6¶vS¦fÇWGFW"ö7WW'F–æòæF'Bs°Ğ¦–×÷'Bw6¶vS¦fÇWGFW"÷6W'f–6W2æF'Bs°Ğ¦–×÷'Bw6¶vS¦fÇWGFW"öÖFW&–ÂæF'Bs°Ğ¦–×÷'Bw6¶vS§7W&6UöfÇWGFW"÷7W&6UöfÇWGFW"æF'Bs°Ğ Ğ¦–×÷'BrââòââöÖöFVÇ2ööÖöFVÇ2æF'Bs°Ğ¦–×÷'Brââòââ÷6W'f–6W2ö÷7FFRæF'Bs°Ğ¦–×÷'Brââòââ÷6W'f–6W2öWF…÷&W÷6—F÷'’æF'Bs°Ğ¦–×÷'Brââòââ÷6W'f–6W2ö&6¶VæEö6öæf–ræF'Bs°Ğ¦–×÷'Brââòââ÷WF–Ç2÷GW&¶—6…÷†öæUö–çWEöf÷&ÖGFW"æF'Bs°Ğ¦–×÷'Brââòââ÷v–FvWG2÷vV'6—FUö&ÇW'&VEö&6¶w&÷VæBæF'Bs°Ğ Ğ¦6Æ72WF…67&VVâW‡FVæG27FFVgVÅv–FvWB°Ğ¢6öç7BWF…67&VVâ‡·7WW"æ¶W’Â&WV—&VBF†—2æ7FFRÂF†—2æöäWF†VçF–6FVGÒ“°Ğ Ğ¢f–æÂ7FFR7FFS°Ğ¢f–æÂfÇVT6†ævVCÅW6W%&öÆSãòöäWF†VçF–6FVC°Ğ Ğ¢÷fW'&–FPĞ¢7FFSÄWF…67&VVãâ7&VFU7FFR‚’ÓâôWF…67&VVå7FFR‚“°Ğ§ĞĞ Ğ¦6Æ72ôWF…67&VVå7FFRW‡FVæG27FFSÄWF…67&VVãâ°Ğ¢7FF–26öç7B&ööÂöFVÖôÆöv–äVæ&ÆVBÒ&ööÂæg&öÔVçf—&öæÖVçB€Ğ¢tTä$ÄUôDTÔõôÄôt”ârÀĞ¢“°Ğ¢f–æÂöf÷&Ô¶W’ÒvÆö&Ä¶W“Äf÷&Õ7FFSâ‚“°Ğ¢f–æÂ÷†öæT6öçG&öÆÆW"ÒFW‡DVF—F–æt6öçG&öÆÆW"‚“°Ğ¢f–æÂ÷77v÷&D6öçG&öÆÆW"ÒFW‡DVF—F–æt6öçG&öÆÆW"‚“°Ğ¢f–æÂö÷G6öçG&öÆÆW"ÒFW‡DVF—F–æt6öçG&öÆÆW"‚“°Ğ¢f–æÂ÷77v÷&Dfö7W4æöFRÒfö7W4æöFR‚“°Ğ Ğ¢&ööÂö—5&Vv—7FW&–ærÒfÇ6S°Ğ¢&ööÂö—4FÖ–âÒfÇ6S°Ğ¢&ööÂö—577v÷&Ef—6–&ÆRÒfÇ6S°Ğ¢&ööÂö—4ÆöF–ærÒfÇ6S°Ğ¢&ööÂöv—F–æt÷GÒfÇ6S°Ğ¢&ööÂ÷&W6WE77v÷&DfÆ÷rÒfÇ6S°Ğ¢&ööÂ÷&W6WE77v÷&E&VG’ÒfÇ6S°Ğ¢&ööÂ÷77v÷&DF÷G4ÆF6†VBÒfÇ6S°Ğ Ğ¢÷fW'&–FPĞ¢fö–B–æ—E7FFR‚’°Ğ¢7WW"æ–æ—E7FFR‚“°Ğ¢÷77v÷&Dfö7W4æöFRæx×í¢G§²ÚîÆ­yÑck onPressed;

  @override
  Widget build(BuildContext context) {
    final color = isAdmin
        ? const Color(0xFFE11D48)
        : AppGlass.textMuted(context);
    return Center(
      child: Semantics(
        button: true,
        label: isAdmin ? 'MÃ¼ÅŸteri giriÅŸi' : 'YÃ¶netici giriÅŸi',
        child: Tooltip(
          message: isAdmin ? 'MÃ¼ÅŸteri giriÅŸi' : 'YÃ¶netici giriÅŸi',
          child: CupertinoButton(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(24),
            onPressed: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isAdmin
                    ? const Color(0xFFE11D48)
                          .withValues(alpha: isDark ? 0.17 : 0.10)
                    : Colors.transparent,
                border: Border.all(
                  color: isAdmin
                      ? const Color(0xFFE11D48).withValues(alpha: 0.54)
                      : AppGlass.dividerColor(context),
                ),
              ),
              child: Icon(
                CupertinoIcons.checkmark_shield_fill,
                size: 21,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
