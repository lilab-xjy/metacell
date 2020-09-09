#' wrap up an atlas object from mc, mc2d and matrix ids
#'
#' This is not doing much more than generating a list with the relevant object names bundeled. To be enhnaced at some stage.
#'
#' @param mat_id id of metacell object ina scdb
#' @param mc_id id of metacell object ina scdb
#' @param gset_id features defining the atlas (to be sued for determing projection)
#' @param mc2d_id projection object id, to define the atlas 2D layout
#'
#' @export

mcell_gen_atlas = function(mat_id, mc_id, gset_id, mc2d_id, atlas_cols = NULL)
{
	return(list(mat_id = mat_id, 
					mc_id = mc_id, 
					gset_id = gset_id,
					mc2d_id = mc2d_id,
					atlas_cols = atlas_cols))
}


#' Project a metacell object on a reference "atlas"
#'
#' This will take each cell in the query object and find its to correlated
#' metacell in the reference, then generating figures showing detailed comparison of how each metacell in the query is distributed in the atlas, and how the pool of all cells in the query MC compare to the pool of their best match projections
#'
#' @param mat_id id of metacell object ina scdb
#' @param mc_id id of metacell object ina scdb
#' @param atlas an object generated by mcell_gen_atlas
#' @param fig_cmp_dir name of directory to put figures per MC 
#'	@param ten2mars should gene mapping be attmpeted using standard MARS-seq to 10x naming convetnion
#' @param gene_name_map if this is dedining a named vector query_name[ref_name], then the name conversion between the query and reference will be determined using it
#' @param md_field metadata field too use as additional factor for plotting subsets
#' @param recolor_mc_id if this is specified,  the atlas colors will be projected on the query MCCs and updated to the scdb object  named recolor_mc
#'	@param plot_all_mc set this to T if you want a plot per metacell to show comparison of query pooled umi's and projected pooled umis.
#'
#' @export
#'

mcell_proj_on_atlas = function(mat_id, mc_id, atlas, 
				fig_cmp_dir, 
				ten2mars=T,
				gene_name_map=NULL,
				recolor_mc_id = NULL,
				plot_all_mcs = F,
				md_field=NULL,
				max_entropy=2,
				burn_cor=0.6)
{
	ref_mc = scdb_mc(atlas$mc_id)
	if(is.null(ref_mc)) {
		stop("mc id ", ref_mc_id, " is missing")
	}
	query_mc = scdb_mc(mc_id)
	if(is.null(query_mc)) {
		stop("mc id ", mc_id, " is missing")
	}
	mat = scdb_mat(mat_id)
	if(is.null(mat)) {
		stop("mat id ", mat_id, " is missing")
	}

	gset = scdb_gset(atlas$gset_id)
	if(is.null(gset)) {
		stop("gset id ", feat_gset_id, " is missing")
	}
	ref_mc2d = scdb_mc2d(atlas$mc2d_id)
	if(is.null(ref_mc2d)) {
		stop("ref_mc2d  ", ref_mc2d, " is missing")
	}

	if(is.null(gene_name_map)) {
		if(ten2mars) {
			gene_name_map = gen_10x_mars_gene_match(mars_mc_id = mc_id, tenx_mc_id = atlas$mc_id)
		} else {
			gene_name_map = rownames(query_mc@e_gc)
			names(gene_name_map) = gene_name_map
		} 
	}

#check cor of all cells, features
	common_genes_ref = names(gset@gene_set)
	common_genes_ref = common_genes_ref[!is.na(gene_name_map[common_genes_ref])]
	common_genes_ref = intersect(common_genes_ref, rownames(ref_mc@e_gc))
	common_genes_ref = common_genes_ref[!is.na(gene_name_map[common_genes_ref])]
	common_genes_ref = common_genes_ref[gene_name_map[common_genes_ref] %in% rownames(query_mc@e_gc)]
	common_genes_ref = common_genes_ref[gene_name_map[common_genes_ref] %in% rownames(mat@mat)]
	common_genes = gene_name_map[common_genes_ref]
	if(mean(!is.null(common_genes)) < 0.5) {
		stop("less than half of the atlas feature genes can be mapped to reference gene names. Probably should provide a name conversion table")
	}
	#browser()
	feats = mat@mat[common_genes, names(query_mc@mc)]
	rownames(feats) = common_genes_ref

	ref_abs_lfp = log(1e-6+ref_mc@e_gc[common_genes_ref,])
	ref_abs_fp = ref_mc@e_gc[common_genes_ref,]

	cross = tgs_cor((cbind(ref_abs_lfp, as.matrix(feats))))
	cross1 = cross[1:ncol(ref_abs_lfp),ncol(ref_abs_lfp)+1:ncol(feats)]

	f = rowSums(is.na(cross1))
	cross1[f,] = 0

	best_ref = as.numeric(unlist(apply(cross1,2,function(x) names(which.max(x)))))
	best_ref_cor = apply(cross1, 2, max)

#	browser()
	c_nms = names(query_mc@mc)
	mc_proj_col_p = table(query_mc@mc[c_nms], ref_mc@colors[best_ref])
	mc_proj_col_p = mc_proj_col_p/rowSums(mc_proj_col_p)
	query_entropy = apply(mc_proj_col_p, 1, 
					function(x) { p =x/sum(x); lp =log2(p+1e-6); return(sum(-p*lp)) })
	
	if(!is.null(recolor_mc_id)) {
		proj_col=ref_mc@colors[as.numeric(unlist(best_ref))]
		new_col=tapply(proj_col,
						   query_mc@mc,
							function(x) { names(which.max(table(x))) }
							)
		query_mc@colors = new_col
		query_mc@colors[query_entropy > max_entropy] = "gray"
		scdb_add_mc(recolor_mc_id, query_mc)
	}

	if(!is.null(fig_cmp_dir)) { 
		if(!dir.exists(fig_cmp_dir)) {
			dir.create(fig_cmp_dir)
		}
		png(sprintf("%s/comp_2d.png", fig_cmp_dir), w=1200, h=1200)
	}
	layout(matrix(c(1,2),nrow=2), h=c(1,4))
	par(mar=c(0,3,2,3))
	plot(best_ref_cor[order(query_mc@mc)], pch=19, col=ref_mc@colors[best_ref[order(query_mc@mc)]],cex=0.6)
	grid()
	par(mar=c(3,3,0,3))
	n = length(best_ref)
	xrange = 0.02*(max(ref_mc2d@mc_x) - min(ref_mc2d@mc_x))
	yrange = 0.02*(max(ref_mc2d@mc_y) - min(ref_mc2d@mc_y))
	ref_x = ref_mc2d@mc_x[best_ref]+rnorm(n, 0, xrange)
	ref_y = ref_mc2d@mc_y[best_ref]+rnorm(n, 0, yrange)
	xlim = c(min(ref_mc2d@mc_x), max(ref_mc2d@mc_x))
	ylim = c(min(ref_mc2d@mc_y), max(ref_mc2d@mc_y))
	plot(ref_x, ref_y, pch=19, col=ref_mc@colors[best_ref], ylim=ylim, xlim=xlim)
	if(!is.null(fig_cmp_dir)) {
		dev.off()
	} else {
		return
	}
	
	query_mc_on_ref = t(tgs_matrix_tapply(ref_abs_fp[,best_ref], 
																query_mc@mc, mean))
	rownames(query_mc_on_ref) = common_genes
	cmp_lfp_1 = log2(1e-6+query_mc_on_ref)
	cmp_lfp_1n = cmp_lfp_1 - rowMeans(cmp_lfp_1)
	cmp_lfp_2 = log2(1e-6+query_mc@e_gc[common_genes,])
	cmp_lfp_2n = cmp_lfp_2 - rowMeans(cmp_lfp_2)
	cmp_lfp_n = cbind(cmp_lfp_1n, cmp_lfp_2n)
	n = ncol(cmp_lfp_n)/2
	cross = tgs_cor(cmp_lfp_n)

	if(is.null(atlas$atlas_cols)) {
		atlas_cols = colnames(mc_proj_col_p)
	} else {
		atlas_cols = atlas$atlas_cols
	}
	png(sprintf("%s/query_color_dist.png", fig_cmp_dir),w=600,h=150+12*nrow(mc_proj_col_p))
	layout(matrix(c(1,2),nrow=1),widths=c(5,2))
	par(mar=c(2,3,2,0))
	barplot(t(mc_proj_col_p[,atlas_cols]), col=atlas_cols, horiz=T, las=2)
	par(mar=c(2,0,2,3))
	barplot(query_entropy, col=query_mc@colors, horiz=T, las=2)
	grid()
	dev.off()

	png(sprintf("%s/query_ref_cmp.png", fig_cmp_dir),w=600,h=600)
	shades = colorRampPalette(c("black", "darkblue", "white", "darkred", "yellow"))(1000)
	layout(matrix(c(1,4,2,3),nrow=2), h=c(10,1), w=c(1,10))
	par(mar=c(0,3,2,0))
	query_ref_colors = table(query_mc@mc, ref_mc@colors[best_ref])
	query_mc_top_color = colnames(query_ref_colors)[apply(query_ref_colors,1,which.max)]
	image(t(as.matrix(1:length(query_mc@colors),nrow=1)), 
									col=query_mc_top_color, yaxt='n', xaxt='n')
	mtext(1:n,at=seq(0,1,l=n),side=2, las=1)
	par(mar=c(0,0,2,2))
	image(pmin(pmax(cross[1:n, n+(1:n)],-burn_cor),burn_cor), col=shades,xaxt='n', yaxt='n', zlim=c(-burn_cor, burn_cor))
	par(mar=c(3,0,0,2))
	image(as.matrix(1:length(query_mc@colors),nrow=1), 
									col=query_mc@colors, yaxt='n', xaxt='n')
	mtext(1:n,at=seq(0,1,l=n),side=1, las=1)
	dev.off()

	if(plot_all_mcs) {
	ref_glob_p = rowMeans(ref_abs_fp)
	for(mc_i in 1:ncol(query_mc@mc_fp)) {
		ref_lfp = sort((query_mc_on_ref[,mc_i]+1e-5)/(ref_glob_p+1e-5))
		ref_marks = gene_name_map[names(tail(ref_lfp,15))]
		fig_nm = sprintf("%s/%d.png", fig_cmp_dir, mc_i)
		png(fig_nm, w=800, h=1200)
		layout(matrix(c(1,2), nrow=2))
	
		mcell_plot_freq_compare(query_mc@e_gc[common_genes,mc_i], 
						query_mc_on_ref[,mc_i], 
						n_reg = 1e-5,
						top_genes=20,
						highlight_genes = ref_marks,
						fig_h=600, fig_w=800,
						lab1="query", lab2="reference", 
						main=sprintf("reference/query, compare mc %d", mc_i))
		par(mar=c(2,2,2,2))
		plot(ref_mc2d@sc_x, ref_mc2d@sc_y, cex=0.2, pch=19, col="gray")
		f = query_mc@mc==mc_i
		points(ref_x[f], ref_y[f], pch=19, col=ref_mc@colors[best_ref[f]])
		dev.off()
		
	}
	}
	if(!is.null(md_field)) {
		md = mat@cell_metadata
		if(md_field %in% colnames(md)) {
			md_vs = md[names(query_mc@mc),md_field]
			for(v in unique(md_vs)) {
				fig_nm = sprintf("%s/md_%s.png", fig_cmp_dir, v)
				png(fig_nm, w=800,h=800)
				f = (md_vs == v)
				plot(ref_mc2d@sc_x, ref_mc2d@sc_y, cex=0.2, pch=19, col="gray")
				points(ref_x[f], ref_y[f], pch=19, col=ref_mc@colors[best_ref[f]])
				dev.off()
			}
		} else {
			message("MD field ", md_field, " not found")
		}
	}
	return(query_mc_on_ref)
	#plot compare_bulk
}
