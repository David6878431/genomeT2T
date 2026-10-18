#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"


cd $workdir
mkdir -p 22.MCScanX_circos
cd 22.MCScanX_circos

ln -s ../21.genefunction/genome.final.gff3  .
ln -s ../21.genefunction/pep.fa  protein.fa
ln -s ../14.Repeat/4.RepeatMasker/genome.fa.masked  genome.fa
ln -s ../14.Repeat/genome.all.repeat.sorted.gff .

mkdir -p MCScanX
cd MCScanX
perl $scriptsdir/geneid_to_mRNAid.pl ../genome.final.gff3 geneid_to_mRNAid.txt
#获取基因对应的蛋白序列信息，注意：基因的第一个转录本为代表序列；
#从geneid2mRNAid.txt文件中每个基因挑一个转录本ID存储到allmRNAID.txt（一列）
cut -f 6 geneid_to_mRNAid.txt >allmRNAID.txt

#获取基因组基因对应转录本的位置信息
perl $scriptsdir/get_mRNA_position.pl allmRNAID.txt ../genome.final.gff3 genes.gff

#获取对应蛋白序列
perl $scriptsdir/get_fa_by_id.pl allmRNAID.txt ../protein.fa pep.fa

#blast建库
makeblastdb -in pep.fa  -dbtype prot -title pep.fa

#blastall  比对，所有基因对所有基因
blastall -i pep.fa -d pep.fa -e 1e-10  -p blastp  -b 5 -v 5 -m 8 -o genes.blast

#运行MCSCANX  查找共线性  得到共线性结果文件：*collinearity
MCScanX genes

###################################
# 整理数据准备绘制 基因组circos图
###################################

cd ..
mkdir -p circos
cd circos

#提取共线性结果，并生成circos需要的link格式文件
perl $scriptsdir/mcscanX2sync.pl -gff ../MCScanX/genes.gff   -colline ../MCScanX/genes.collinearity    -name genome


## 获得染色体长度
samtools faidx  ../genome.fa
awk '{print $1"\t"$2}' ../genome.fa.fai >genome.len

## 生成染色体文件 7列，  karyotype.txt 文件行的顺序决定了染色体顺序，可以手动调整
sort -k1,1 genome.len | awk '{print "chr\t-\t"$1"\t"$1"\t0\t"$2"\tchr"NR}'  > karyotype.txt

## 生成窗口文件， 窗口大小300Kb，如果基因组大可适当调大, 可以用基因组大小除以窗口大小，总窗口数在2000以内为佳
bedtools  makewindows -w "$CIRCOS_WINDOW" -g  genome.len > genome.window.bed

## 计算每个窗口平均GC含量
seqtk subseq ../genome.fa  genome.window.bed  > genome.window.fa
seqtk comp  genome.window.fa |awk '{print $1 "\t" ($4+$5)/($3+$4+$5+$6) } ' |awk -F ":|-" '{print $1"\t"$2"\t"$3"\t"$4}'> gc_density.txt

## 计算每个窗口基因条数
awk '$3=="gene"{print}' ../genome.final.gff3 >gene.gff
bedtools intersect  -a genome.window.bed -b gene.gff   -c -F 0.1  > genedensity.txt

## 计算每个窗口重复序列含量
###################参考基因组重复区屏蔽，注意不屏蔽短重复############################
#区分简单重复序列和复杂重复序列

awk '$3=="TandemRepeat"{print}' ../genome.all.repeat.sorted.gff >repeat.TandemRepeat.gff
awk '$3=="Transposon"{print}' ../genome.all.repeat.sorted.gff >repeat.TransposonElement.gff
grep -i "Class=LTR/Gypsy" ../genome.all.repeat.sorted.gff >repeat.LTR_Gypsy.gff
grep -i "Class=LTR/Copia" ../genome.all.repeat.sorted.gff >repeat.LTR_Copia.gff

#统计数据
bedtools coverage -a  genome.window.bed -b  repeat.LTR_Gypsy.gff |awk '{print $1 "\t" $2 "\t" $3 "\t" $7}' > LTR_Gypsy.coverage.txt
bedtools coverage -a  genome.window.bed -b  repeat.LTR_Copia.gff |awk '{print $1 "\t" $2 "\t" $3 "\t" $7}' > LTR_Copia.coverage.txt
bedtools coverage -a  genome.window.bed -b  repeat.TransposonElement.gff |awk '{print $1 "\t" $2 "\t" $3 "\t" $7}' > TransposonElement.coverage.txt
#tandam 覆盖度小 统计密度（数量）
bedtools intersect  -a genome.window.bed -b repeat.TandemRepeat.gff  -c -F 0.1  > TandemRepeat.density.txt

#准备circos配置文件 config.txt
echo "
karyotype = karyotype.txt #指定染色体文件
chromosomes_units = 500000  #设置长度单位，表示500k长度的序列代表为1u
chromosomes_display_default = yes #默认是将所有的染色体都展示出来
show_tick_labels=yes
show_ticks=yes

##ideogram 染色体和刻度线配置
<ideogram>
    fill=yes
    label_font=default
    label_parallel=yes
    label_radius=dims(image,radius)-60p
    label_size=45
    radius=0.90r
    show_label=yes
    <spacing>
        default=10u  #染色体之间间隙
        </spacing>
    stroke_color=dgrey
    stroke_thickness=2p
    thickness=30p
</ideogram>
<ticks> #设置染色体刻度
    color=black
    format=%d
    multiplier=1e-6
    radius=1r
    thickness=2p
    <tick>
        size=10p
        spacing=5u
    </tick>
    <tick>
        color=black
        format=%d
        label_offset=10p
        label_size=25p
        show_label=yes
        size=15p
        spacing=25u
        thickness=4p
    </tick>
</ticks>


############plots##############
track_start = 0.99 #track 起始位置
track_width = 0.05 #track宽度
track_pad   = 0.01 #不同track 之间间隙


<plots>
    <plot>
         type=histogram  # histogram指定绘制直方图 line为折线图，scatter为散点图，heatmap为热图
        fill_color=set1-9-qual-1
        color=black
        file=genedensity.txt
        r1  = eval(sprintf(\"%fr\",conf(track_start)-counter(plot)*(conf(track_width)+conf(track_pad))))
        r0  = eval(sprintf(\"%fr\",conf(track_start)-counter(plot)*(conf(track_width)+conf(track_pad))-conf(track_width)))

        thickness=2

        <backgrounds> #背景颜色灰色
            <background>
                color = vlgrey
            </background>
        </backgrounds>
    </plot>
    <plot>
        type=histogram
        extend_bin = no #直方图是由bin所构成,若bins 在坐标上不相连，最好设置不要将其bins连接到一起。
        file=gc_density.txt
        fill_color=set1-9-qual-2
        color=black
        r1  = eval(sprintf(\"%fr\",conf(track_start)-counter(plot)*(conf(track_width)+conf(track_pad))))
        r0  = eval(sprintf(\"%fr\",conf(track_start)-counter(plot)*(conf(track_width)+conf(track_pad))-conf(track_width)))
        #stroke_type=both
        thickness=2
        <backgrounds> #背景颜色灰色
            <background>
                color = vlgrey
            </background>
        </backgrounds>
    </plot>

    <plot>
         type=histogram  # histogram指定绘制直方图 line为折线图，scatter为散点图，heatmap为热图
        fill_color=set1-9-qual-3
        file=TransposonElement.coverage.txt
        r1  = eval(sprintf(\"%fr\",conf(track_start)-counter(plot)*(conf(track_width)+conf(track_pad))))
        r0  = eval(sprintf(\"%fr\",conf(track_start)-counter(plot)*(conf(track_width)+conf(track_pad))-conf(track_width)))

        thickness=2
        #color=black
        <backgrounds> #背景颜色灰色
            <background>
                color = vlgrey
            </background>
        </backgrounds>
    </plot>
    <plot>
        type=histogram
        file=LTR_Copia.coverage.txt
        extend_bin = no #直方图是由bin所构成,若bins 在坐标上不相连，最好设置不要将其bins连接到一起
        fill_color=set1-9-qual-4
        #color=black
        #r1=0.66r
        #r0=0.56r
        r1  = eval(sprintf(\"%fr\",conf(track_start)-counter(plot)*(conf(track_width)+conf(track_pad))))
        r0  = eval(sprintf(\"%fr\",conf(track_start)-counter(plot)*(conf(track_width)+conf(track_pad))-conf(track_width)))

        #stroke_type=both
        thickness=2
        <backgrounds> #背景颜色灰色
            <background>
                color = vlgrey
            </background>
        </backgrounds>
    </plot>
    <plot>
        type=histogram
        file=LTR_Gypsy.coverage.txt
        extend_bin = no #直方图是由bin所构成,若bins 在坐标上不相连，最好设置不要将其bins连接到一起。
        fill_color=set1-9-qual-5
        #color=black
        r1  = eval(sprintf(\"%fr\",conf(track_start)-counter(plot)*(conf(track_width)+conf(track_pad))))
        r0  = eval(sprintf(\"%fr\",conf(track_start)-counter(plot)*(conf(track_width)+conf(track_pad))-conf(track_width)))

        #stroke_type=both
        thickness=2
        <backgrounds> #背景颜色灰色
            <background>
                color = vlgrey
            </background>
        </backgrounds>
    </plot>
    <plot>
        type  = heatmap # 指定绘图类型为heatmap
        file  = TandemRepeat.density.txt # 设定数据文件路径
        r1  = eval(sprintf(\"%fr\",conf(track_start)-counter(plot)*(conf(track_width)+conf(track_pad))))
        r0  = eval(sprintf(\"%fr\",conf(track_start)-counter(plot)*(conf(track_width)+conf(track_pad))-conf(track_width)))
        #color   = spectral-5-div
        color   = reds-9-seq #reds-9-seq  blues-9-seq
        scale_log_base = 2  # 设定 scale_log_base 参数 数据转换 : http://circos.ca/documentation/tutorials/2d_tracks/heat_maps/images
    </plot>


</plots>

<links>  #共线性links
    <link>
        file=genome.blocklink.txt
        bezier_radius=0r  # #设置贝塞尔曲线半径，该值设大后曲线扁平。
        bezier_radius_purity=0.75
        color=set2-8-qual-7
        crest=0.5
        #radius=0.33r. #    手动设置半径
        radius=eval(sprintf(\"%fr\",conf(track_start)-5*(conf(track_width)+conf(track_pad))-conf(track_width)-conf(track_pad))) #自动设置半径，前面6个plot 这里是5，因为索引从0开始
        thickness=2  #设置 link 曲线的粗细
        ribbon=yes  #条带yes,线 no
        z=20
        <rules>
            <rule>   #染色体间连线颜色
                color=green
                condition=var(interchr)
            </rule>
            <rule> ##染色体内部连线颜色
                color=red
                condition=var(intrachr)
            </rule>
        </rules>
    </link>

</links>

<colors>
<<include etc/colors.conf>>
<<include etc/brewer.conf>>
#<<include etc/colors_fonts_patterns.conf>>
#<<include colors.ucsc.conf>>
#<<include colors.hsv.conf>>
</colors>

<fonts>
<<include etc/fonts.conf>>
</fonts>

<image>
<<include etc/image.conf>>
</image>
<<include etc/housekeeping.conf>>

" >config.txt

#准备好之后可以绘图

circos -conf config.txt -outputdir ./ -outputfile circos
