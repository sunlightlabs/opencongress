var BillCards = React.createClass({
  render: function(){
    var billNode = this.props.bills.map(function(bill, iteration){
      return <BillCard bill={bill} key={iteration} />;
    });

    return (
      <div className="contents__main">
        <h1>Bills</h1>  
        <div>{billNode}</div>
      </div>
    )
  }
}); 