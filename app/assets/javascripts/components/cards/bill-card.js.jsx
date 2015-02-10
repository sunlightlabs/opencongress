var BillCard = React.createClass({

  buildTitle: function(){
    if (this.props.bill.short_title) {
      return <CardTitle title={this.props.bill.short_title} />
    } else {
      return <CardTitle title={this.props.bill.bill_type + this.props.bill.number} />
    }
  },

  render: function(){
    var billLink = this.props.bill.bill_type + this.props.bill.number + "-" + this.props.bill.session +"/show";
    return (
      <div className="card">
        <div className="card--info">
          {this.buildTitle()}
          <CardSummary summary={this.props.bill.summary} link={billLink} />
          <CardDate date={this.props.bill.introduced} />
        </div>
        <div className="card--info__footer">
        </div>
      </div>
    );
  }
});
