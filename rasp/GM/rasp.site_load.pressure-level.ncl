;;; TO ALTER RESSURE LEVEL PLOT SECTION
; PAULS - Change limits for feet/min

; NB: opts_bparam for contours
;     opts_w      for wind barbs


;if( Region .eq. "UK2+1" ) then
;    opts_bparam@ContourParameters = (/ -450., 450., 50. /)
;else
;    opts_bparam@colorMap = "steprev18"
;    opts_bparam@ContourParameters = (/ -200., 200., 25. /)
    opts_bparam@colorMap = "press26"
    opts_bparam@ContourParameters = (/ -300., 300., 25. /)
;end if



; Zou mooi zijn als onderstaande plot waar hoge rh/wolken zijn net zoals in XBL plot maar werkt niet
;contourLines = "rh"

; Hieronder mislukte pogingen om geen waarde bij de labelbar einden te krijgen
;if( plot_param .eq. "press795" ) then
;opts_bparam = true
;opts_bparam@cnExplicitLabelBarLabelsOn = false
;opts_bparam@cnLabelBarEndStyle = "IncludeOuterBoxes"
;opts_bg = true
;opts_bg@cnLabelBarEndStyle = "IncludeOuterBoxes"
;opts_cn = true
;opts_cn@cnExplicitLabelBarLabelsOn = false
;opts_cn@cnLabelBarEndStyle = "IncludeOuterBoxes"
;opts = true
;opts@cnExplicitLabelBarLabelsOn = false
;opts@cnLabelBarEndStyle = "IncludeOuterBoxes"
;opts_ws = true
;opts_ws@cnExplicitLabelBarLabelsOn = false
;opts_ws@cnLabelBarEndStyle = "IncludeOuterBoxes"
;opts_lb = true
;opts_lb@cnExplicitLabelBarLabelsOn = false
;opts_lb@cnLabelBarEndStyle = "IncludeOuterBoxes"
;end if


