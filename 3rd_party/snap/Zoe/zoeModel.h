/******************************************************************************\
zoeModel.h - part of the ZOE library for genomic analysis
 
 Copyright (C) 2002-2013 Ian F. Korf

\******************************************************************************/

#ifndef ZOE_MODEL_H
#define ZOE_MODEL_H

#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "zoeDNA.h"
#include "zoeMath.h"
#include "zoeFeature.h"
#include "zoeTools.h"

typedef enum {
	UNDEFINED_MODEL,
	WMM,  /* Weight Matrix Model */
	LUT,  /* Lookup Table (aka Markov Model) */
	SAM,  /* Scoring Array Model */
	SDT,  /* Sequence Decision Tree */
	CDS,  /* 3 Periodic (LUT submodels) */
	MIX,  /* averages all submodels */
	TRM   /* terminal model - always MIN_SCORE */
} zoeModelType;

struct zoeModel  {
	zoeModelType       type;      /* enumerated above */
	char             * name;      /* enumerated above, but also used by SDT */
	coor_t             length;    /* length of the model - how many bp covered */
	coor_t             focus;     /* which bp of model gets score */
	coor_t             max_left;  /* maximum bp left of focus */
	coor_t             max_right; /* maximum bp right of focus */
	int                symbols;   /* number of symbols in the alphabet */
	int                submodels; /* number of sub-models */
	struct zoeModel ** submodel;  /* sub-models, for complex models */
	score_t          * data;      /* scores (not for complex models) */
	score_t            score;     /* base score - probability of branch, WMM only */
};
typedef struct zoeModel * zoeModel;

void     zoeDeleteModel (zoeModel);
zoeModel zoeNewModel (void);
zoeModel zoeReadModel (FILE *);
zoeModel zoeReadModelHeader (FILE *, score_t);
void     zoeWriteModel (FILE *, const zoeModel);
void     zoeWriteModelHeader (FILE *, const zoeModel);
void     zoeAmbiguateModel (zoeModel, score_t);
void     zoeDeambiguateModel (zoeModel);
zoeModel zoeGetModel (const char *);
zoeModel zoeGetModelHeader (const char *, score_t);
coor_t   zoeModelLengthLeft (const zoeModel);
coor_t   zoeModelLengthRight (const zoeModel);
zoeModel zoeNewCodingModel (int, float);
zoeModel zoeNewIntronModel (int, float);
zoeModel zoeNewInterModel (int, float);
zoeModel zoeNewAcceptorModel (int, int, float);
zoeModel zoeNewDonorModel (int, int, float);
zoeModel zoeNewStartModel (int, int, float);
zoeModel zoeNewStopModel (int, float);
zoeModel zoeNewUTR5Model (int, float);
zoeModel zoeNewUTR3Model (int, float);
zoeModel zoeNewPolyAModel (int, int, float);

#endif
